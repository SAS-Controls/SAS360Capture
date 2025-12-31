//
//  CVWrapper.h
//  SAS360Capture
//
//  Objective-C wrapper for OpenCV panorama stitching
//  This allows Swift to use OpenCV's C++ stitching functionality
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CVWrapper : NSObject

/// Stitch multiple images into a panorama
/// @param images Array of UIImage objects to stitch (should be in order, with overlap)
/// @return Stitched panorama image, or nil if stitching failed
+ (UIImage * _Nullable)stitchImages:(NSArray<UIImage *> *)images;

/// Stitch images with specified mode
/// @param images Array of UIImage objects to stitch
/// @param mode Stitching mode: 0 = PANORAMA (for wide scenes), 1 = SCANS (for flat surfaces)
/// @return Stitched panorama image, or nil if stitching failed
+ (UIImage * _Nullable)stitchImages:(NSArray<UIImage *> *)images mode:(int)mode;

/// Process images for 360 spherical panorama
/// @param images Array of UIImage objects captured in a 360 rotation
/// @return Equirectangular panorama image suitable for 360 viewing
+ (UIImage * _Nullable)stitch360Images:(NSArray<UIImage *> *)images;

@end

NS_ASSUME_NONNULL_END
