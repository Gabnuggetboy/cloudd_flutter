import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      return ClipRRect(borderRadius: borderRadius, child: imageWidget);
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
}
