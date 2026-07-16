import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/colors.dart';

class PasscodeScreen extends StatefulWidget {
  final bool isSetupMode; // true = setup new PIN, false = unlock app
  final VoidCallback onSuccess;

  const PasscodeScreen({
    super.key,
    required this.isSetupMode,
    required this.onSuccess,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  String _enteredPin = "";
  String _firstEnteredPin = ""; // For setup confirmation
  String _headerText = "";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _headerText = widget.isSetupMode ? "Choose a 4-Digit Passcode" : "Enter Passcode";
  }

  Future<void> _handleKeyPress(String value) async {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += value;
      _hasError = false;
    });

    if (_enteredPin.length == 4) {
      // Delay briefly so the user sees the last dot fill
      await Future.delayed(const Duration(milliseconds: 150));
      _processPin();
    }
  }

  void _handleBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _processPin() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.isSetupMode) {
      if (_firstEnteredPin.isEmpty) {
        // First entry done, ask to confirm
        setState(() {
          _firstEnteredPin = _enteredPin;
          _enteredPin = "";
          _headerText = "Confirm Your Passcode";
        });
      } else {
        if (_enteredPin == _firstEnteredPin) {
          // Passcodes match, save and exit
          await prefs.setString("app_passcode", _enteredPin);
          widget.onSuccess();
        } else {
          // Mismatch
          setState(() {
            _enteredPin = "";
            _firstEnteredPin = "";
            _hasError = true;
            _headerText = "Mismatched. Start Over";
          });
        }
      }
    } else {
      final savedPin = prefs.getString("app_passcode");
      if (_enteredPin == savedPin) {
        widget.onSuccess();
      } else {
        setState(() {
          _enteredPin = "";
          _hasError = true;
          _headerText = "Incorrect Passcode";
        });
      }
    }
  }

  Widget _buildDot(int index) {
    bool isFilled = _enteredPin.length > index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 18,
      width: 18,
      decoration: BoxDecoration(
        color: isFilled
            ? (_hasError ? Colors.redAccent : WAColors.primary)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: _hasError
              ? Colors.redAccent
              : (isFilled ? WAColors.primary : Colors.grey.shade600),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String label, {VoidCallback? onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onPressed ?? () => _handleKeyPress(label),
      child: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? WAColors.backgroundDark : WAColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // App Brand Header
              const Text(
                "us",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _headerText,
                style: TextStyle(
                  fontSize: 16,
                  color: _hasError
                      ? Colors.redAccent
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  fontWeight: _hasError ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              
              const SizedBox(height: 35),
              
              // Keypad Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) => _buildDot(index)),
              ),
              
              const Spacer(),
              
              // Keypad Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton("1"),
                        _buildKeypadButton("2"),
                        _buildKeypadButton("3"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton("4"),
                        _buildKeypadButton("5"),
                        _buildKeypadButton("6"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildKeypadButton("7"),
                        _buildKeypadButton("8"),
                        _buildKeypadButton("9"),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Left empty space or Cancel button
                        const SizedBox(width: 72, height: 72),
                        _buildKeypadButton("0"),
                        GestureDetector(
                          onTap: _handleBackspace,
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: Icon(
                              Icons.backspace_outlined,
                              color: isDark ? Colors.white70 : Colors.black87,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
