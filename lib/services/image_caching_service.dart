import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudd_flutter/models/experience.dart';

class ImageCacheService {
  // Singleton 
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  Widget getCachedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
      cacheKey: imageUrl,
      maxWidthDiskCache: 1000,
      maxHeightDiskCache: 1000,
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  // Use this when u need ImageProvider, this will help to cache images 
  ImageProvider getCachedImageProvider(String imageUrl) {
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: imageUrl,
      maxWidth: 1000,
      maxHeight: 1000,
    );
  }

  // Pre-caches a list of image URLs in the background.
  // Useful for preloading images that will be displayed soon
  Future<void> preCacheImages(List<String> imageUrls, BuildContext context) async {
    for (final url in imageUrls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(url), context);
        } catch (e) {
          debugPrint('Failed to pre-cache image: $url - $e');
        }
      }
    }
  }

  // Pre-caches images for a list of experiences
  // This is called after fetching experiences to look nicer
  Future<void> preCacheExperienceImages(
    List<Experience> experiences,
    BuildContext context,
  ) async {
    final urls = experiences
        .where((e) => e.imageUrl != null && e.imageUrl!.isNotEmpty)
        .map((e) => e.imageUrl!)
        .toList();
    await preCacheImages(urls, context);
  }

  // To clear cache entirely
  Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
    debugPrint('Image cache cleared');
  }

  // To remove a specific image from cache
  Future<void> removeFromCache(String imageUrl) async {
    await CachedNetworkImage.evictFromCache(imageUrl);
    debugPrint('Evicted from cache: $imageUrl');
  }
}
