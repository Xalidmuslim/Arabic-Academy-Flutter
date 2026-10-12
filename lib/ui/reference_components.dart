import 'package:flutter/material.dart';
import 'neumorphic_components.dart';

const refGreen = Color(0xFF526B40);
const refCream = Color(0xFFF2E8D9);

/// Compatibility wrappers preserve existing call sites and navigation.
class ReferenceFeatureTile extends StatelessWidget {
  const ReferenceFeatureTile({
    super.key, required this.title, required this.subtitle,
    required this.image, required this.onTap,
  });
  final String title, subtitle, image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NeumorphicFeatureTile(
    title: title, subtitle: subtitle, image: image, onTap: onTap);
}

class ReferenceCourseHero extends StatelessWidget {
  const ReferenceCourseHero({
    super.key, required this.progress, required this.completed,
    required this.total, required this.onContinue,
  });

  final double progress;
  final int completed, total;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => NeumorphicCourseHero(
    progress: progress, completed: completed,
    total: total, onContinue: onContinue);
}

class ReferencePhotoHeader extends StatelessWidget {
  const ReferencePhotoHeader({super.key,required this.title,required this.subtitle});
  final String title,subtitle;
  @override
  Widget build(BuildContext context)=>Container(
    height:153,clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(color:refGreen,borderRadius:BorderRadius.circular(22)),
    child:Stack(fit:StackFit.expand,children:[
      Image.asset('assets/images/feature_teacher.webp',fit:BoxFit.cover),
      const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(
        colors:[Color(0xE307382D),Color(0x9907382D),Color(0x2807382D)]))),
      Padding(padding:const EdgeInsets.all(17),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.end,
        children:[
          Text(title,style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w800)),
          const SizedBox(height:5),
          Text(subtitle,maxLines:2,style:const TextStyle(color:Colors.white,fontSize:12)),
        ])),
    ]),
  );
}
