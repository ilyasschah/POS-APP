import 'package:flutter/material.dart';

class ServiceStatusHelper {
  static Color getColor(int status) {
    switch (status) {
      case 0:
        return const Color(0xFF10B981);
      case 1:
        return const Color(0xFF3B82F6); // Vibrant Blue
      case 2:
        return const Color(0xFFF59E0B); // Amber/Orange
      case 3:
        return const Color(0xFF14B8A6); // Teal
      default:
        return Colors.blueGrey;
    }
  }

  static LinearGradient getGradient(int status) {
    switch (status) {
      case 0:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );
      case 1:
        return const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        );
      default:
        return const LinearGradient(colors: [Colors.blueGrey, Colors.grey]);
    }
  }

  static IconData getIcon(int status) {
    switch (status) {
      case 0:
        return Icons.check_circle_outline;
      case 1:
        return Icons.people;
      case 2:
        return Icons.local_fire_department;
      case 3:
        return Icons.room_service;
      default:
        return Icons.help_outline;
    }
  }

  static String getLabel(int status) {
    switch (status) {
      case 0:
        return "Free";
      case 1:
        return "Occupied";
      case 2:
        return "In Preparation";
      case 3:
        return "In Kitchen";
      default:
        return "Unknown";
    }
  }
}
