import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original lightweight vector study objects, not stock Material icons.
/// Used only for explicitly recognized vocabulary concepts. Other words
/// retain their Arabic text rather than receive a misleading picture.
class SemanticObjectArtwork extends StatelessWidget {
  const SemanticObjectArtwork({super.key, required this.concept,
    this.size = 100});
  final String concept;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: size, width: size,
    child: CustomPaint(painter: _ObjectPainter(concept)),
  );
}

class _ObjectPainter extends CustomPainter {
  const _ObjectPainter(this.concept);
  final String concept;
  static const olive = Color(0xFF82927D);
  static const pale = Color(0xFFD7DCC3);
  static const terra = Color(0xFFC18A6F);
  static const wood = Color(0xFFB08C6B);
  static const ivory = Color(0xFFFFF9EA);
  static const ink = Color(0xFF546A60);

  void box(Canvas c, double x, double y, double w, double h,
      Color color, [double radius=6]) =>
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(x,y,w,h), Radius.circular(radius)),
      Paint()..color=color);
  void oval(Canvas c, double x, double y, double w, double h,
      Color color) => c.drawOval(Rect.fromLTWH(x,y,w,h),Paint()..color=color);
  void circ(Canvas c, double x,double y,double r,Color color) =>
    c.drawCircle(Offset(x,y),r,Paint()..color=color);
  void line(Canvas c, double ax,double ay,double bx,double by,
      Color color,double width) =>
    c.drawLine(Offset(ax,ay),Offset(bx,by),
      Paint()..color=color..strokeWidth=width..strokeCap=StrokeCap.round);
  void poly(Canvas c, List<Offset> points,Color color) {
    if(points.isEmpty) return;
    final p=Path()..moveTo(points.first.dx,points.first.dy);
    for(final pt in points.skip(1)) {p.lineTo(pt.dx,pt.dy);}
    p.close();
    c.drawPath(p,Paint()..color=color);
  }
  void window(Canvas c,double x,double y) {
    box(c,x,y,32,34,ink,3);
    box(c,x+4,y+4,24,26,const Color(0xFFBDD1C9),2);
    line(c,x+16,y+3,x+16,y+32,ivory,3);
    line(c,x+3,y+16,x+29,y+16,ivory,3);
  }
  void building(Canvas c,{Color facade=terra,bool school=false,
      bool hospital=false,bool mosque=false,bool shop=false}) {
    box(c,25,46,110,88,facade,5);
    box(c,25,45,110,10,ivory,3);
    if(mosque){
      poly(c,[const Offset(48,46),const Offset(80,13),
          const Offset(112,46)],olive);
      line(c,118,23,118,46,ink,5);
      circ(c,118,19,5,olive);
    }else if(shop){
      poly(c,[const Offset(23,45),const Offset(39,25),
          const Offset(122,25),const Offset(138,45)],olive);
      for(var i=0;i<4;i++) box(c,31+i*24.0,48,18,13,ivory,2);
    }else if(hospital){
      box(c,61,24,38,35,ivory,5);
      box(c,75,29,10,25,terra,1);
      box(c,68,36,24,10,terra,1);
    }else if(school){
      box(c,45,31,70,18,olive,3);
    }else{
      poly(c,[const Offset(18,47),const Offset(80,10),
          const Offset(141,47)],olive);
    }
    window(c,36,68);window(c,92,68);
    box(c,70,97,24,37,ink,3);
    circ(c,89,117,2,ivory);
  }
  void human(Canvas c,{bool coat=false}) {
    oval(c,48,116,75,10,const Color(0x26594735));
    poly(c,[const Offset(61,57),const Offset(99,57),
      const Offset(111,125),const Offset(50,125)],
      coat?ivory:olive);
    oval(c,63,15,36,48,wood);
    oval(c,68,24,27,32,const Color(0xFFDDC0A2));
    if(coat){
      line(c,80,65,80,118,olive,3);
      line(c,76,84,97,84,ink,3);
    }
  }

  @override
  void paint(Canvas canvas,Size size) {
    canvas.save();
    canvas.scale(size.width/160,size.height/160);
    // Slight ground shadow and small environment vignette for tactile depth.
    oval(canvas,25,134,110,13,const Color(0x25594839));
    switch(concept) {
      case 'book':
        poly(canvas,[const Offset(17,46),const Offset(75,57),
          const Offset(75,122),const Offset(19,109)],wood);
        poly(canvas,[const Offset(76,57),const Offset(142,42),
          const Offset(142,108),const Offset(76,122)],olive);
        poly(canvas,[const Offset(23,39),const Offset(76,51),
          const Offset(76,113),const Offset(24,102)],ivory);
        poly(canvas,[const Offset(76,51),const Offset(137,37),
          const Offset(137,102),const Offset(76,113)],const Color(0xFFE8E3D3));
        line(canvas,76,52,76,112,wood,2);
      case 'pen':
        canvas.save();canvas.translate(80,78);canvas.rotate(math.pi/4);
        box(canvas,-10,-61,20,115,olive,8);
        box(canvas,-10,-61,20,12,ivory,2);
        box(canvas,-6,-42,5,70,const Color(0x88FFFFFF),2);
        poly(canvas,[const Offset(-10,54),const Offset(10,54),
          const Offset(0,71)],wood);
        poly(canvas,[const Offset(-4,65),const Offset(4,65),
          const Offset(0,75)],ink);
        canvas.restore();
      case 'house':
        building(canvas);
      case 'school':
        building(canvas,facade:const Color(0xFFC6AA8D),school:true);
      case 'mosque':
        building(canvas,facade:const Color(0xFFD4BCA0),mosque:true);
      case 'hospital':
        building(canvas,facade:const Color(0xFFC7D1BA),hospital:true);
      case 'market':
        building(canvas,facade:const Color(0xFFD9B79A),shop:true);
      case 'door':
        box(canvas,39,13,82,127,wood,6);
        box(canvas,46,20,68,113,terra,4);
        box(canvas,56,30,48,43,const Color(0x32FFFAE9),5);
        box(canvas,56,80,48,43,const Color(0x32FFF9E9),5);
        circ(canvas,104,85,5,ivory);
      case 'window':
        box(canvas,18,22,124,120,wood,8);
        box(canvas,27,31,106,102,const Color(0xFFA3C8BD),5);
        line(canvas,81,31,81,135,ivory,8);
        line(canvas,25,81,135,81,ivory,7);
      case 'bag':
        box(canvas,44,45,72,94,olive,18);
        box(canvas,56,26,47,40,wood,19);
        box(canvas,57,46,45,81,olive,8);
        box(canvas,52,82,57,41,const Color(0xFFAAB89A),8);
        box(canvas,66,91,30,9,wood,4);
      case 'car':
        box(canvas,22,75,116,51,olive,17);
        poly(canvas,[const Offset(41,76),const Offset(58,49),
          const Offset(104,49),const Offset(122,77)],
          const Color(0xFFA3B4A6));
        box(canvas,64,55,34,21,const Color(0xFFD5E8E6),4);
        circ(canvas,52,124,15,ink);circ(canvas,111,124,15,ink);
        circ(canvas,52,124,6,ivory);circ(canvas,111,124,6,ivory);
      case 'tree':
        box(canvas,74,88,17,48,wood,4);
        circ(canvas,80,66,37,olive);
        circ(canvas,57,86,25,const Color(0xFFA5B695));
        circ(canvas,106,82,29,const Color(0xFF8DA98C));
      case 'flower':
        box(canvas,77,79,6,55,olive,3);
        for(var i=0;i<5;i++){
          final angle=math.pi*2*i/5;
          circ(canvas,80+24*math.cos(angle),
            65+24*math.sin(angle),15,terra);
        }
        circ(canvas,80,65,14,ivory);
        oval(canvas,54,95,25,11,olive);
      case 'clock':
        circ(canvas,80,79,62,wood);circ(canvas,80,79,56,ivory);
        line(canvas,80,79,80,44,ink,5);
        line(canvas,80,79,108,87,ink,4);
        circ(canvas,80,79,5,olive);
      case 'sun':
        for(var i=0;i<12;i++){
          final a=i*math.pi/6;
          line(canvas,80+44*math.cos(a),79+44*math.sin(a),
            80+60*math.cos(a),79+60*math.sin(a),wood,6);
        }
        circ(canvas,80,79,35,terra);
      case 'moon':
        circ(canvas,80,79,49,wood);
        circ(canvas,102,57,45,const Color(0xFFFFFAEF));
      case 'water':
        box(canvas,51,30,58,101,const Color(0x66A8C4C3),8);
        box(canvas,55,75,50,50,const Color(0xFF9AC7CA),5);
        line(canvas,55,29,105,29,ivory,4);
      case 'cup':
        box(canvas,44,52,68,70,ivory,11);
        oval(canvas,44,48,68,18,wood);
        oval(canvas,52,53,51,9,const Color(0xFF886848));
        line(canvas,112,68,134,78,wood,12);
        line(canvas,134,78,116,101,wood,12);
      case 'apple':
        circ(canvas,78,92,44,terra);
        oval(canvas,77,40,29,11,olive);
        line(canvas,82,55,86,35,ink,5);
        oval(canvas,54,65,12,16,const Color(0x66FFF6E8));
      case 'bread':
        box(canvas,30,80,99,48,wood,17);
        oval(canvas,30,55,99,62,terra);
        for(var i=0;i<3;i++)line(canvas,55+i*26.0,74,
          63+i*26.0,90,ivory,4);
      case 'chair':
        box(canvas,38,22,72,75,olive,9);
        box(canvas,39,92,89,15,wood,4);
        line(canvas,51,106,46,138,ink,8);
        line(canvas,115,106,121,138,ink,8);
      case 'phone':
        box(canvas,45,14,72,126,ink,13);
        box(canvas,51,23,60,105,const Color(0xFFABC7B9),7);
        box(canvas,62,42,37,27,ivory,7);
        circ(canvas,80,133,3,ivory);
      case 'computer':
        box(canvas,20,30,120,78,ink,5);
        box(canvas,27,37,106,63,const Color(0xFFABC8C8),2);
        box(canvas,74,108,12,18,wood,1);
        box(canvas,50,126,61,8,ink,4);
      case 'key':
        circ(canvas,55,55,28,wood);
        circ(canvas,55,55,13,ivory);
        line(canvas,74,75,118,119,wood,14);
        line(canvas,112,116,131,99,wood,11);
      case 'plane':
        poly(canvas,[const Offset(18,90),const Offset(65,74),
          const Offset(70,23),const Offset(85,17),
          const Offset(91,74),const Offset(140,91),
          const Offset(139,108),const Offset(92,97),
          const Offset(97,131),const Offset(81,137),
          const Offset(68,133),const Offset(69,97),
          const Offset(20,108)],olive);
        box(canvas,74,37,8,50,ivory,3);
      case 'cat':
      case 'cow':
      case 'horse':
        oval(canvas,38,64,84,58,olive);
        poly(canvas,[const Offset(44,71),const Offset(52,36),
          const Offset(68,65)],wood);
        poly(canvas,[const Offset(94,66),const Offset(109,35),
          const Offset(116,76)],wood);
        oval(canvas,61,96,40,28,const Color(0xFFE4C7A9));
      case 'fish':
        oval(canvas,40,60,86,60,olive);
        poly(canvas,[const Offset(51,88),const Offset(13,56),
          const Offset(14,127)],terra);
        poly(canvas,[const Offset(75,68),const Offset(97,38),
          const Offset(106,68)],wood);
      case 'shirt':
        poly(canvas,[const Offset(59,30),const Offset(102,30),
          const Offset(139,67),const Offset(118,92),
          const Offset(104,79),const Offset(105,133),
          const Offset(53,133),const Offset(53,79),
          const Offset(39,92),const Offset(21,67)],olive);
        poly(canvas,[const Offset(61,29),const Offset(80,52),
          const Offset(101,29)],ivory);
      case 'doctor':
        human(canvas,coat:true);
      case 'kitchen':
      case 'food':
        oval(canvas,27,88,105,44,wood);
        oval(canvas,34,82,91,38,ivory);
        oval(canvas,51,84,55,30,olive);
        circ(canvas,67,93,11,terra);
        circ(canvas,91,102,9,terra);
      default:
        // No unrelated placeholder icon for a concept without drawing.
        box(canvas,33,43,94,77,ivory,11);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ObjectPainter oldDelegate) =>
      concept != oldDelegate.concept;
}
