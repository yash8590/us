import 'package:flutter/material.dart';
import '../utils/colors.dart';

class WALoadingWidget extends StatelessWidget {
  final String? message;

  const WALoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(WAColors.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
