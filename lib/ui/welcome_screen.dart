
import 'package:flutter/material.dart';

class ReferenceWelcomeScreen extends StatelessWidget {
  const ReferenceWelcomeScreen({super.key,required this.onStart});
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context)=>Scaffold(
    body:Stack(fit:StackFit.expand,children:[
      Image.asset('assets/images/feature_welcome.webp',
        fit:BoxFit.cover,alignment:Alignment.center),
      const DecoratedBox(decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[Color(0x12FFF7E9),Color(0x7EFFF5E4),Color(0xECFFF6E8)],
          stops:[0,0.52,1]))),
      SafeArea(child:Padding(
        padding:const EdgeInsets.fromLTRB(26,24,26,28),
        child:Column(children:[
          const Spacer(flex:5),
          const Text('Арабский ближе,\nчем ты думаешь',
            textAlign:TextAlign.center,
            style:TextStyle(color:Color(0xFF073C30),fontSize:32,
              height:1.15,fontWeight:FontWeight.w800)),
          const SizedBox(height:17),
          const Text('Современный и понятный путь\nк изучению арабского языка',
            textAlign:TextAlign.center,
            style:TextStyle(color:Color(0xFF293C35),fontSize:14,height:1.45)),
          const Spacer(flex:3),
          const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            CircleAvatar(radius:4,backgroundColor:Color(0xFF094D3A)),
            SizedBox(width:7),
            CircleAvatar(radius:4,backgroundColor:Color(0xFF9EB3A7)),
            SizedBox(width:7),
            CircleAvatar(radius:4,backgroundColor:Color(0xFF9EB3A7)),
          ]),
          const SizedBox(height:20),
          SizedBox(width:double.infinity,height:54,
            child:FilledButton.icon(
              onPressed:()=>onStart(),
              style:FilledButton.styleFrom(
                backgroundColor:const Color(0xFF073F32),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))),
              icon:const Icon(Icons.arrow_forward_rounded),
              label:const Text('Начать обучение',
                style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
            ),
          ),
          const SizedBox(height:13),
          TextButton(
            onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content:Text('Авторизация по телефону будет подключена на следующем этапе.'))),
            child:const Text('У меня уже есть аккаунт',
              style:TextStyle(color:Color(0xFF183A2F),fontSize:13)),
          ),
        ]),
      )),
    ]),
  );
}
