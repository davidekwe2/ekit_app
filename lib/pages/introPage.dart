import 'package:ekit_app/my%20components/myButtons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade900,
 body: Padding(
   padding: const EdgeInsets.all(16.0),
   child: Column(
     children: [
       //App name
       SizedBox(height: 50,),
       Text("Ekit~Notes",
         style: GoogleFonts.play(
           fontSize: 60,
           fontWeight: FontWeight.bold,
           color: Colors.white,
           letterSpacing: 3.5,
         ),
       ),
       SizedBox(
         height: 20,
       ),
       //ICON
       Padding(
         padding: const EdgeInsets.all(19.0),
         child: Image.asset("lib/assets/images/frogfirstpage.png"),
       ),
       //TITLE
       Text("Note-taking redefined :)",
         style: GoogleFonts.play(
           fontSize: 35,
           fontWeight: FontWeight.bold,
           color: Colors.white,
           letterSpacing: 3.5,
         ),
       ),
        SizedBox(height: 5,),
       //SUBTITLE
       Text("Capture every lecture and turn it into clear, searchable notes — effortlessly. Summaries, translations, and key points all in one place.",
         style: TextStyle(
           color: Colors.white,
           fontSize: 20,
         ),
       ),
       SizedBox(height: 10,),
       
       //GET STARTED BUTTON
       MyButton(textt: "Get Started", icon: Icons.arrow_forward,
         ontap: () {
         Navigator.pushReplacementNamed(context, '/home');
         }

       )
     ],
   ),
 ),
    );
  }
}
