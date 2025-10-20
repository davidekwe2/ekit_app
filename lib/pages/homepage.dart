import 'dart:math' as math;

import 'package:ekit_app/my%20components/myButtons.dart';
import 'package:ekit_app/my%20components/mytextfield.dart';
import 'package:ekit_app/themes/colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/storage/store.dart';
import '../my%20components/mynotes_tile.dart';


class HomePage extends StatelessWidget {
  final TextEditingController searchcontroller = TextEditingController();
   HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final notes = AppStore.notes;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: Icon(Icons.draw_outlined,size: 40,color: Colors.teal[900],),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("EKit-Notes",style: GoogleFonts.playwriteAr(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20,),
            //search bar

            Mytextfields(controller: searchcontroller, hintetxt: "Search through your notes 📚 ", obscureText: false, iconn: Icons.search,
            ),
            SizedBox(height: 20,),
            //image and add start record
            Container(
              decoration:
              BoxDecoration(
                color: PrimaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(

                children: [

                  //column with text and button below
                  Expanded(
                    child: Column(
                      children: [
                        //text
                        Text("Record a new note",
                        style: GoogleFonts.play(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),),
                        SizedBox(height: 20,),
                        //button
                        SizedBox(
                          //width: 200,
                          child: MyButton(textt: "Start", icon: Icons.mic,
                            ontap: () {
                            //add functionality later
                              Navigator.pushNamed(context, '/record');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10,),
                  //image
                  Image.asset("lib/assets/images/frog (1).png",height: 150,fit: BoxFit.contain,)


                ],
              ),

            ),
            SizedBox(height: 30,),
            // recent notes
            Padding(
              padding: const EdgeInsets.only(left: 25.0,right: 20.0),
              child: Row(

                children: [
                  Text("RECENT NOTES",
                  style: GoogleFonts.play(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),),
                  Spacer(),
                  TextButton(onPressed: (){
                    Navigator.pushNamed(context, '/categories');
                  }, child: Text("View All",
                  style: TextStyle(
                      color: Colors.teal[900],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),),
                ],
              ),
            ),
            //list of recent notes

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: math.min(notes.length, 5),
                itemBuilder: (context, i) {
                  final n = notes[i];
                  return MyNotesTile(
                    note: n,
                    onPlay: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Play tapped')),
                      );
                    },
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
