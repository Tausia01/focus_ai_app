import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    this.title = 'FocusAI',
    this.actions,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA), // soft neutral white-grey
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent, // use parent background
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leadingWidth: showBackButton ? 56 : 48,

        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Colors.black87),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Image.asset(
                  'assets/focus_ai_icon.png',
                  width: 32,
                  height: 32,
                ),
              ),

        title: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: Colors.grey.shade900,
            fontFamily: 'Inter', // modern clean font (add to pubspec)
          ),
        ),

        centerTitle: true,

        actions: actions != null
            ? actions!.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: w,
                );
              }).toList()
            : null,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
