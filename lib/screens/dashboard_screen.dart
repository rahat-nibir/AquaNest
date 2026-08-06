import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // --- Dynamic States ---
  // 1. Schedules Data
  List<Map<String, dynamic>> schedules = [
    {
      'time': '08:00 AM',
      'subtitle': 'Every day · Standard portion',
      'isActive': true,
    },
    {
      'time': '06:30 PM',
      'subtitle': 'Mon, Wed, Fri · Small portion',
      'isActive': false,
    },
  ];

  // 2. Camera Snapshots
  int snapshotCount = 0;

  // 3. Aqua AI Messages (Clean Fresh Start)
  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> chatMessages = [
    {
      'sender': 'bot',
      'text': 'Hello! How can I assist you with your aquarium today?',
    },
  ];

  // --- Functions ---
  void _addNewSchedule() async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        final formattedTime = pickedTime.format(context);
        schedules.add({
          'time': formattedTime,
          'subtitle': 'Every day · Standard portion',
          'isActive': true,
        });
      });
    }
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;

    String userMsg = _chatController.text.trim();
    setState(() {
      chatMessages.add({'sender': 'user', 'text': userMsg});
      _chatController.clear();
    });

    // Simulated Bot Response
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          chatMessages.add({
            'sender': 'bot',
            'text':
                'I am monitoring the system regarding: "$userMsg". Everything remains under normal parameters.',
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E17),
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildScheduleTab(),
                _buildCameraTab(),
                _buildAquaAiTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildBottomNavBar()),
        ],
      ),
    );
  }

  // ================= TAB 0: HOME =================
  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Welcome Back 👋',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'AquaNest Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildGlassIconButton(Icons.notifications_none_rounded, () {}),
            ],
          ),
          const SizedBox(height: 24),
          _buildGlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    color: Color(0xFF00E5FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Living Room Reef',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Status: Stable (26.5°C)',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ================= TAB 1: SCHEDULE =================
  Widget _buildScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Schedule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Automated feeding cycles',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Dynamic Schedule List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = schedules[index];
              return _buildScheduleCard(
                item['time'],
                item['subtitle'],
                item['isActive'],
                (val) {
                  setState(() {
                    schedules[index]['isActive'] = val;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 20),

          // Add New Time Button
          GestureDetector(
            onTap: _addNewSchedule,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                color: Colors.transparent,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add New Time',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'View Feed History Logs',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF00E5FF),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ================= TAB 2: CAMERA =================
  Widget _buildCameraTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camera',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        CircleAvatar(radius: 3, backgroundColor: Colors.red),
                        SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(
                    'ESP32-CAM  ·  720p',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save Snapshot
          GestureDetector(
            onTap: () {
              setState(() {
                snapshotCount++;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Snapshot saved!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Save Snapshot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Recent Gallery ($snapshotCount Saved)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
                  height: 95,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131C2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (index < snapshotCount)
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: (index < snapshotCount)
                          ? const Color(0xFF00E5FF)
                          : Colors.white24,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ================= TAB 3: AQUA AI =================
  Widget _buildAquaAiTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Aqua AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Smart Assistant',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                  ),
                ],
              ),
              // Refresh / Reset Chat
              _buildGlassIconButton(Icons.refresh_rounded, () {
                setState(() {
                  chatMessages = [
                    {
                      'sender': 'bot',
                      'text':
                          'Hello! How can I assist you with your aquarium today?',
                    },
                  ];
                });
              }),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: chatMessages.length,
            itemBuilder: (context, index) {
              final msg = chatMessages[index];
              if (msg['sender'] == 'bot') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBotAvatar(),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F30),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            msg['text'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (msg['sender'] == 'user') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg['text'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),

        // Text Input Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 95),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Ask Aqua AI...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= TAB 4: SETTINGS =================
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          _buildGlassCard(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF3B82F6)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'RN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Md Rahat Al Islam Nibir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'rahat@aquanest.app',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildGlassIconButton(Icons.edit_outlined, () {}),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'DEVICE MANAGEMENT',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B182B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth,
                    color: Color(0xFF00E5FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pair New Device',
                        style: TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Connect Hub or ESP32',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF00E5FF),
                  size: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildGlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.memory,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Living Room Reef',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: Color(0xFF00E676),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.tune_rounded, color: Colors.white54, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ================= UI HELPERS =================
  Widget _buildScheduleCard(
    String time,
    String subtitle,
    bool isActive,
    ValueChanged<bool> onChanged,
  ) {
    return _buildGlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isActive ? const Color(0xFF00E5FF) : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Switch(
            value: isActive,
            activeThumbColor: const Color(0xFF00E5FF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: const Icon(
        Icons.smart_toy_outlined,
        color: Color(0xFF00E5FF),
        size: 16,
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 18),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, 0),
                _buildNavItem(Icons.access_time_rounded, 1),
                _buildNavItem(Icons.camera_alt_outlined, 2),
                _buildNavItem(Icons.smart_toy_outlined, 3),
                _buildNavItem(Icons.person_outline_rounded, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: isSelected
            ? const BoxDecoration(
                color: Color(0xFF00E5FF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00E5FF),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              )
            : null,
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white38,
          size: 22,
        ),
      ),
    );
  }
}
