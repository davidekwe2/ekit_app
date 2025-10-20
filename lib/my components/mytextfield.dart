import 'package:flutter/material.dart';

class Mytextfields extends StatelessWidget {
  final TextEditingController controller;
  final String hintetxt;
  final bool obscureText;
  final IconData? iconn;

  const Mytextfields({
    super.key,
    required this.controller,
    required this.hintetxt,
    required this.obscureText,
    this.iconn,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 17),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintetxt,
          hintStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
          filled: false,
          prefixIcon: iconn != null
              ? Icon(
            iconn,
            color: Colors.teal[900],
            size: 30,
          )
              : null,

          // Normal border
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.teal, width: 4),
            borderRadius: BorderRadius.circular(20),
          ),

          // Focused border (when user taps the field)
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),

        ),
      ),
    );
  }
}
