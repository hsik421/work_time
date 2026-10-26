import 'package:flutter/material.dart';
import 'package:work_time/domain/work_entry.dart';

const positiveColor = Color(0xff16763c);
const negativeColor = Color(0xffb3261e);
Color entryColor(WorkEntry? entry) => (entry?.differenceMinutes ?? 0) > 0
    ? positiveColor
    : (entry?.differenceMinutes ?? 0) < 0
    ? negativeColor
    : Colors.black;
