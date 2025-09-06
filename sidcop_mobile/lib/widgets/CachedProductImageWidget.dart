import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ProductPreloadService.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.dart';

/// Widget para mostrar imágenes de productos con caché offline
class CachedProductImageWidget extends StatelessWidget {
  final Productos product;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showPlaceholder;

  const CachedProductImageWidget({
    Key? key,
    required this.product,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showPlaceholder = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final preloadService = ProductPreloadService();
    
    Widget imageWidget = preloadService.getCachedProductImage(
      imageUrl: product.prod_Imagen,
      productId: product.prod_Id.toString(),
      width: width,
      height: height,
      fit: fit,
      placeholder: showPlaceholder ? _buildPlaceholder() : null,
      errorWidget: _buildErrorWidget(),
    );

    // Aplicar border radius si se especifica
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Widget placeholder mientras carga la imagen
  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
          ),
          SizedBox(height: 8),
          Text(
            'Cargando imagen...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'Satoshi',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Widget de error cuando no se puede cargar la imagen
  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey[400],
            size: width != null ? width! * 0.3 : 40,
          ),
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Sin imagen',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontFamily: 'Satoshi',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget para mostrar imagen de producto en formato card
class ProductImageCard extends StatelessWidget {
  final Productos product;
  final VoidCallback? onTap;
  final bool showProductInfo;

  const ProductImageCard({
    Key? key,
    required this.product,
    this.onTap,
    this.showProductInfo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen del producto
            Expanded(
              flex: showProductInfo ? 3 : 1,
              child: CachedProductImageWidget(
                product: product,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                  bottom: showProductInfo ? Radius.zero : Radius.circular(12),
                ),
              ),
            ),
            
            // Información del producto (opcional)
            if (showProductInfo) ...[
              Expanded(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        product.prod_Descripcion ?? 'Sin descripción',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.prod_PrecioUnitario != null) ...[
                        SizedBox(height: 4),
                        Text(
                          '\$${product.prod_PrecioUnitario!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar imagen de producto en lista
class ProductImageListTile extends StatelessWidget {
  final Productos product;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ProductImageListTile({
    Key? key,
    required this.product,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 56,
        height: 56,
        child: CachedProductImageWidget(
          product: product,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text(
        product.prod_Descripcion ?? 'Sin descripción',
        style: TextStyle(
          fontFamily: 'Satoshi',
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '\$${product.prod_PrecioUnitario.toStringAsFixed(2)}',
        style: TextStyle(
          color: Colors.green[700],
          fontWeight: FontWeight.w500,
          fontFamily: 'Satoshi',
        ),
      ),
      trailing: trailing,
    );
  }
}
