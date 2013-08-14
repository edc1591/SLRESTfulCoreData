//
//  SLRESTfulCoreDataObjectCache.m
//  SLRESTfulCoreData
//
//  Created by Oliver Letterer on 31.07.13.
//  Copyright 2013 Sparrow-Labs. All rights reserved.
//

#import "SLRESTfulCoreDataObjectCache.h"
#import "SLAttributeMapping.h"
#import "SLObjectConverter.h"
#import "SLObjectDescription.h"

#import "NSManagedObject+SLRESTfulCoreDataSetup.h"
#import "NSManagedObject+SLRESTfulCoreDataHelpers.h"

#import <objc/runtime.h>



@interface SLRESTfulCoreDataObjectCache () {
    
}

@property (nonatomic, strong) NSCache *internalCache;

@end





@implementation SLRESTfulCoreDataObjectCache

#pragma mark - Initialization

- (NSCache *)internalCache
{
    if (!_internalCache) {
        _internalCache = [[NSCache alloc] init];
    }
    
    return _internalCache;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    if (self = [super init]) {
        _managedObjectContext = context;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_managedObjectContextDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:context];
    }
    return self;
}

- (id)objectOfClass:(Class)class withRemoteIdentifier:(id)identifier
{
    while ([class class] != class) {
        class = [class class];
    }
    
    NSString *cachedKey = [self _cachedKeyForClass:class withRemoteIdentifier:identifier];
    id cachedManagedObject = [self.internalCache objectForKey:cachedKey];
    
    if (cachedManagedObject) {
        return cachedManagedObject;
    }
    
    NSAssert([class isSubclassOfClass:[NSManagedObject class]], @"class %@ must be a subclass of NSManagedObject", class);
    NSManagedObjectContext *context = self.managedObjectContext;
    
    SLAttributeMapping *attributeMapping = [class attributeMapping];
    SLObjectConverter *objectConverter = [class objectConverter];
    
    NSString *uniqueKeyForJSONDictionary = [class objectDescription].uniqueIdentifierOfJSONObjects;
    NSString *managedObjectUniqueKey = [attributeMapping convertJSONObjectAttributeToManagedObjectAttribute:uniqueKeyForJSONDictionary];
    
    id managedObjectID = [objectConverter managedObjectObjectFromJSONObjectObject:identifier
                                                        forManagedObjectAttribute:managedObjectUniqueKey];
    
    if (!managedObjectID) {
        NSLog(@"WARNING: cannot convert JSON object %@ into CoreData object", identifier);
        return nil;
    }
    
    NSAssert([[class registeredAttributeNames] containsObject:managedObjectUniqueKey], @"no unique key attribute found to %@. tried to map %@ to %@", class, uniqueKeyForJSONDictionary, managedObjectUniqueKey);
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:NSStringFromClass(class) inManagedObjectContext:context];
    NSAttributeDescription *attributeDescription = entityDescription.attributesByName[managedObjectUniqueKey];
    
    NSAssert(attributeDescription != nil, @"no attributeDescription found for %@[%@]", class, managedObjectUniqueKey);
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(class)];
    
    if (attributeDescription.attributeType == NSStringAttributeType) {
        request.predicate = [NSPredicate predicateWithFormat:@"%K LIKE %@", managedObjectUniqueKey, managedObjectID];
    } else {
        request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", managedObjectUniqueKey, managedObjectID];
    }
    
    NSError *error = nil;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    NSAssert(error == nil, @"error while fetching: %@", error);
    
    if (objects.count > 0) {
        id managedObject = objects[0];
        
        [self.internalCache setObject:managedObject forKey:cachedKey];
        return objects[0];
    }
    
    return nil;
}

#pragma mark - Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Private category implementation ()

- (void)_managedObjectContextDidChange:(NSNotification *)notification
{
    NSArray *deletedObjects = notification.userInfo[NSDeletedObjectsKey];
    
    for (NSManagedObject *deletedObject in deletedObjects) {
        Class class = NSClassFromString(deletedObject.entity.name);
        
        NSString *uniqueKeyForJSONDictionary = [class objectDescription].uniqueIdentifierOfJSONObjects;
        NSString *managedObjectUniqueKey = [[class attributeMapping] convertJSONObjectAttributeToManagedObjectAttribute:uniqueKeyForJSONDictionary];
        
        if ([class instancesRespondToSelector:NSSelectorFromString(managedObjectUniqueKey)]) {
            id identifier = [deletedObject valueForKey:managedObjectUniqueKey];
            NSString *cachedKey = [self _cachedKeyForClass:class withRemoteIdentifier:identifier];
            [self.internalCache removeObjectForKey:cachedKey];
        }
    }
}

- (NSString *)_cachedKeyForClass:(Class)class withRemoteIdentifier:(id)identifier
{
    while ([class class] != class) {
        class = [class class];
    }
    
    return [NSString stringWithFormat:@"%@#%@", NSStringFromClass(class), identifier];
}

@end



#pragma mark - Singleton implementation

@implementation SLRESTfulCoreDataObjectCache (Singleton)

+ (SLRESTfulCoreDataObjectCache *)sharedCacheForManagedObjectContext:(NSManagedObjectContext *)context
{
    SLRESTfulCoreDataObjectCache *cache = objc_getAssociatedObject(context, _cmd);
    
    if (!cache) {
        cache = [[SLRESTfulCoreDataObjectCache alloc] initWithManagedObjectContext:context];
        objc_setAssociatedObject(context, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return cache;
}

@end
