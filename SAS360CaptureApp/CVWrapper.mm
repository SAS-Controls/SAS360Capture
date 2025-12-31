//
//  CVWrapper.mm
//  SAS360Capture
//
//  Objective-C++ implementation for OpenCV panorama stitching
//

// Must import UIKit BEFORE OpenCV to avoid macro conflicts
#import <UIKit/UIKit.h>
#import "CVWrapper.h"

// Undefine conflicting macros before importing OpenCV
#undef NO
#undef YES

#import <opencv2/opencv.hpp>
#import <opencv2/stitching.hpp>
#import <opencv2/imgcodecs/ios.h>

// Restore macros after OpenCV
#define YES ((BOOL)1)
#define NO ((BOOL)0)

@implementation CVWrapper

+ (UIImage * _Nullable)stitchImages:(NSArray<UIImage *> *)images {
    return [self stitchImages:images mode:0]; // Default to PANORAMA mode
}

+ (UIImage * _Nullable)stitchImages:(NSArray<UIImage *> *)images mode:(int)mode {
    if (images.count < 2) {
        NSLog(@"CVWrapper: Need at least 2 images to stitch");
        return nil;
    }
    
    NSLog(@"CVWrapper: Starting stitch with %lu images", (unsigned long)images.count);
    
    // Convert UIImages to cv::Mat
    std::vector<cv::Mat> cvImages;
    
    for (UIImage *image in images) {
        cv::Mat cvImage;
        UIImageToMat(image, cvImage);
        
        if (cvImage.empty()) {
            NSLog(@"CVWrapper: Failed to convert image to Mat");
            continue;
        }
        
        // Convert RGBA to RGB if needed
        if (cvImage.channels() == 4) {
            cv::cvtColor(cvImage, cvImage, cv::COLOR_RGBA2RGB);
        }
        
        // Resize if image is too large (memory optimization)
        int maxDimension = 1500;
        if (cvImage.cols > maxDimension || cvImage.rows > maxDimension) {
            double scale = (double)maxDimension / std::max(cvImage.cols, cvImage.rows);
            cv::resize(cvImage, cvImage, cv::Size(), scale, scale, cv::INTER_AREA);
        }
        
        cvImages.push_back(cvImage);
        NSLog(@"CVWrapper: Added image %lu, size: %dx%d", (unsigned long)cvImages.size(), cvImage.cols, cvImage.rows);
    }
    
    if (cvImages.size() < 2) {
        NSLog(@"CVWrapper: Not enough valid images to stitch");
        return nil;
    }
    
    // Create stitcher
    cv::Stitcher::Mode stitchMode = (mode == 0) ? cv::Stitcher::PANORAMA : cv::Stitcher::SCANS;
    cv::Ptr<cv::Stitcher> stitcher = cv::Stitcher::create(stitchMode);
    
    // Configure for better results
    stitcher->setPanoConfidenceThresh(0.5);
    
    cv::Mat result;
    cv::Stitcher::Status status = stitcher->stitch(cvImages, result);
    
    if (status != cv::Stitcher::OK) {
        NSLog(@"CVWrapper: Stitching failed with status: %d", status);
        switch (status) {
            case cv::Stitcher::ERR_NEED_MORE_IMGS:
                NSLog(@"CVWrapper: Need more images or more overlap between images");
                break;
            case cv::Stitcher::ERR_HOMOGRAPHY_EST_FAIL:
                NSLog(@"CVWrapper: Homography estimation failed - images may not have enough features");
                break;
            case cv::Stitcher::ERR_CAMERA_PARAMS_ADJUST_FAIL:
                NSLog(@"CVWrapper: Camera parameters adjustment failed");
                break;
            default:
                break;
        }
        return nil;
    }
    
    NSLog(@"CVWrapper: Stitching successful! Result size: %dx%d", result.cols, result.rows);
    
    // Convert back to UIImage
    UIImage *resultImage = MatToUIImage(result);
    return resultImage;
}

+ (UIImage * _Nullable)stitch360Images:(NSArray<UIImage *> *)images {
    if (images.count < 4) {
        NSLog(@"CVWrapper: Need at least 4 images for 360 stitch");
        return nil;
    }
    
    NSLog(@"CVWrapper: Starting 360 stitch with %lu images", (unsigned long)images.count);
    
    // Convert UIImages to cv::Mat
    std::vector<cv::Mat> cvImages;
    
    for (UIImage *image in images) {
        cv::Mat cvImage;
        UIImageToMat(image, cvImage);
        
        if (cvImage.empty()) {
            continue;
        }
        
        if (cvImage.channels() == 4) {
            cv::cvtColor(cvImage, cvImage, cv::COLOR_RGBA2RGB);
        }
        
        // Resize for memory efficiency while keeping quality
        int maxDimension = 1200;
        if (cvImage.cols > maxDimension || cvImage.rows > maxDimension) {
            double scale = (double)maxDimension / std::max(cvImage.cols, cvImage.rows);
            cv::resize(cvImage, cvImage, cv::Size(), scale, scale, cv::INTER_AREA);
        }
        
        cvImages.push_back(cvImage);
    }
    
    if (cvImages.size() < 4) {
        NSLog(@"CVWrapper: Not enough valid images for 360 stitch");
        return nil;
    }
    
    // Create stitcher optimized for 360 panoramas
    cv::Ptr<cv::Stitcher> stitcher = cv::Stitcher::create(cv::Stitcher::PANORAMA);
    
    // Configure for spherical/cylindrical projection
    stitcher->setPanoConfidenceThresh(0.3);
    stitcher->setWaveCorrection(true);
    stitcher->setWaveCorrectKind(cv::detail::WAVE_CORRECT_HORIZ);
    
    cv::Mat result;
    cv::Stitcher::Status status = stitcher->stitch(cvImages, result);
    
    if (status != cv::Stitcher::OK) {
        NSLog(@"CVWrapper: 360 stitching failed with status: %d", status);
        
        // Try with default settings as fallback
        NSLog(@"CVWrapper: Trying fallback stitch...");
        cv::Ptr<cv::Stitcher> fallbackStitcher = cv::Stitcher::create(cv::Stitcher::PANORAMA);
        status = fallbackStitcher->stitch(cvImages, result);
        
        if (status != cv::Stitcher::OK) {
            NSLog(@"CVWrapper: Fallback also failed");
            return nil;
        }
    }
    
    NSLog(@"CVWrapper: 360 stitching successful! Result size: %dx%d", result.cols, result.rows);
    
    // Convert back to UIImage
    UIImage *resultImage = MatToUIImage(result);
    return resultImage;
}

@end
