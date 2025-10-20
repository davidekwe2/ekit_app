import 'package:flutter/material.dart';
class MyButton extends StatelessWidget {
  final String textt;
  final IconData? icon;
  final VoidCallback ontap;
  const MyButton({super.key, required this.textt, this.icon,required this.ontap});


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.deepPurple[800],
        ),
        child: Row(
          children: [
            Text(
              textt,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ),
            if (icon != null) ...[
              SizedBox(width: 8), // Space between text and icon
              Icon(icon, color: Colors.white),]
          ],
        ),
      ),
    );
  }
}
