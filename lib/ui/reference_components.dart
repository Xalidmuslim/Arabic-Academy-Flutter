
import 'package:flutter/material.dart';

const refGreen = Color(0xFF083F34);
const refCream = Color(0xFFF8F3EA);

class ReferenceFeatureTile extends StatelessWidget {
  const ReferenceFeatureTile({super.key,required this.title,required this.subtitle,required this.image,required this.onTap});
  final String title, subtitle, image;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFFBF5),
    borderRadius: BorderRadius.circular(18),
    elevation: 1.5,
    shadowColor: const Color(0x24123F35),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E0D3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children:[
          Expanded(flex: 5, child: Image.asset(image,fit:BoxFit.cover,
            filterQuality:FilterQuality.medium)),
          Expanded(flex: 3,child: Padding(
            padding: const EdgeInsets.fromLTRB(11,7,7,8),
            child: Column(crossAxisAlignment:CrossAxisAlignment.start,
              mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Color(0xFF18362E),fontSize:14,fontWeight:FontWeight.w800)),
                const SizedBox(height:3),
                Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Color(0xFF6F746D),fontSize:10.5,height:1.2)),
            ]),
          )),
        ]),
      ),
    ),
  );
}

class ReferenceCourseHero extends StatelessWidget {
  const ReferenceCourseHero({super.key,required this.progress,required this.completed,
    required this.total,required this.onContinue});
  final double progress;
  final int completed,total;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Container(
    height:210,
    decoration:BoxDecoration(
      color:refGreen,borderRadius:BorderRadius.circular(24),
      boxShadow:const [BoxShadow(color:Color(0x2A173F32),blurRadius:20,offset:Offset(0,9))]),
    clipBehavior:Clip.antiAlias,
    child:Stack(fit:StackFit.expand,children:[
      Image.asset('assets/images/feature_classroom.webp',
        fit:BoxFit.cover,alignment:Alignment.centerRight),
      const DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,
          colors:[Color(0xFA073F33),Color(0xD2083F34),Color(0x72083F34)]))),
      Padding(padding:const EdgeInsets.all(18),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Мой курс',style:TextStyle(color:Colors.white,fontSize:12)),
          const SizedBox(height:4),
          const Text('Базовый уровень 1',style:TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w800)),
          const SizedBox(height:4),
          Text('Пройдено $completed из $total уроков',
            style:const TextStyle(color:Color(0xFFE8F0EA),fontSize:12)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(8),
              child:LinearProgressIndicator(value:progress.clamp(0.0,1.0),minHeight:7,
                backgroundColor:Colors.white38,color:const Color(0xFFE0C080)))),
            const SizedBox(width:14),
            Container(width:56,height:56,alignment:Alignment.center,
              decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xC30E4236),
                border:Border.all(color:const Color(0xFFE0C080),width:5)),
              child:Text('${(progress*100).round()}%',style:const TextStyle(
                color:Colors.white,fontSize:13,fontWeight:FontWeight.bold))),
          ]),
          const Spacer(),
          SizedBox(height:41,child:FilledButton.icon(
            onPressed:onContinue,
            style:FilledButton.styleFrom(backgroundColor:const Color(0xFFFFFAF2),
              foregroundColor:refGreen,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22))),
            icon:const Icon(Icons.arrow_forward_rounded,size:19),
            label:const Text('Продолжить урок',style:TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
          )),
        ]),
      ),
    ]),
  );
}

class ReferencePhotoHeader extends StatelessWidget {
  const ReferencePhotoHeader({super.key,required this.title,required this.subtitle});
  final String title,subtitle;
  @override
  Widget build(BuildContext context)=>Container(
    height:153,clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(color:refGreen,borderRadius:BorderRadius.circular(22)),
    child:Stack(fit:StackFit.expand,children:[
      Image.asset('assets/images/feature_welcome.webp',fit:BoxFit.cover),
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
