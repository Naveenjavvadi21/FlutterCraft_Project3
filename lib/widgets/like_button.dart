import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;
  final double size;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.count,
    required this.onTap,
    this.size = 22,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                color: widget.isLiked
                    ? AppTheme.likeRed
                    : Theme.of(context).iconTheme.color?.withAlpha(160),
                size: widget.size,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isLiked
                    ? AppTheme.likeRed
                    : Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
