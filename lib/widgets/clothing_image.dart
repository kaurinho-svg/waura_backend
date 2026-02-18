import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ClothingImage extends StatelessWidget {
  final String path;
  final bool isNetwork;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ClothingImage({
    super.key,
    required this.path,
    required this.isNetwork,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        width: width,
        height: height,
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }
    return Image.file(File(path), fit: fit, width: width, height: height);
  }
}
