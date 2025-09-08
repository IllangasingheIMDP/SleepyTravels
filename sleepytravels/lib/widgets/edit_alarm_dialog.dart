import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/alarm_model.dart';
import '../data/repositories/alarm_repository.dart';
import '../core/services/audio_file_service.dart';

class EditAlarmDialog extends StatefulWidget {
  final AlarmModel alarm;
  final AlarmRepository repository;

  const EditAlarmDialog({
    super.key,
    required this.alarm,
    required this.repository,
  });

  @override
  State<EditAlarmDialog> createState() => _EditAlarmDialogState();
}

class _EditAlarmDialogState extends State<EditAlarmDialog> {
  late TextEditingController _radiusController;
  String? _selectedSoundPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _radiusController = TextEditingController(text: widget.alarm.radiusM.toString());
    _selectedSoundPath = widget.alarm.soundPath;
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        final tempPath = result.files.single.path!;
        final originalName = result.files.single.name;

        // Save the file to permanent storage
        final permanentPath = await AudioFileService.instance.saveAudioFile(
          tempPath,
          originalName,
        );

        if (permanentPath != null) {
          setState(() {
            _selectedSoundPath = permanentPath;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Audio file selected: $originalName')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save audio file')),
            );
          }
        }
      }
    } catch (e) {
      print('Error picking audio file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking audio file: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    final radiusText = _radiusController.text.trim();
    
    if (radiusText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a radius')),
      );
      return;
    }

    final radius = int.tryParse(radiusText);
    if (radius == null || radius <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid radius')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Update the alarm in the database
      await widget.repository.updateAlarm(
        widget.alarm.id!,
        radius,
        _selectedSoundPath,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate changes were made
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarm updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating alarm: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating alarm: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getAudioFileName(String? path) {
    if (path == null) return 'No audio selected';
    return path.split('/').last.split('\\').last;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Alarm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Lat: ${widget.alarm.destLat.toStringAsFixed(6)}'),
            Text('Lng: ${widget.alarm.destLng.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            
            const Text(
              'Radius (meters):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter radius in meters',
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Audio File:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getAudioFileName(_selectedSoundPath),
                style: TextStyle(
                  color: _selectedSoundPath != null ? Colors.black : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAudioFile,
                icon: const Icon(Icons.audiotrack),
                label: const Text('Select Audio File'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
