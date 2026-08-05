import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/aquarium_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aquarium = Provider.of<AquariumProvider>(context);
    final data = aquarium.sensorData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaNest Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildStatCard(
              'Temperature',
              '${data.temperature.toStringAsFixed(1)} °C',
              Icons.thermostat,
              Colors.orange,
            ),
            _buildStatCard(
              'Water Level',
              '${data.waterLevel.toStringAsFixed(1)} cm',
              Icons.water,
              Colors.blue,
            ),
            _buildStatCard(
              'Food Level',
              '${data.foodLevel.toStringAsFixed(1)} %',
              Icons.set_meal,
              Colors.green,
            ),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Water Pump',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Switch(
                      value: data.isPumpOn,
                      onChanged: (val) => aquarium.togglePump(val),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => aquarium.triggerFeeder(),
        icon: const Icon(Icons.restaurant),
        label: const Text('Feed Fish'),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
