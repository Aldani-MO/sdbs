import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/wallet_service.dart';
import '../utils/error_handler.dart';
import 'home.dart';
import 'profile.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  final int _selectedIndex = 0; // Cards is selected

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  void _showTopUpDialog({double? presetAmount}) {
    final TextEditingController amountController = TextEditingController(
      text: presetAmount != null ? presetAmount.toStringAsFixed(2) : '',
    );
    bool isToppingUp = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: Colors.green.shade700, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text("Top Up Wallet"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Enter the amount to add to your balance.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Amount",
                      prefixText: "JOD ",
                      prefixStyle: TextStyle(color: Colors.grey[600], fontSize: 22, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.maroon, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (isToppingUp)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      if (amountController.text.isEmpty) return;
                      final double? amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ErrorHandler.showError(context, 'Please enter a valid amount');
                        return;
                      }
                      if (amount > 100) {
                        ErrorHandler.showError(context, 'Maximum top-up is 100 JOD per transaction');
                        return;
                      }

                      setStateDialog(() => isToppingUp = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await Provider.of<WalletService>(context, listen: false)
                              .topUp(user.uid, amount);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ErrorHandler.showSuccess(
                              context,
                              '✅ JOD ${amount.toStringAsFixed(2)} added to your wallet!',
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) ErrorHandler.showError(context, 'Top-up failed: $e');
                      } finally {
                        setStateDialog(() => isToppingUp = false);
                      }
                    },
                    child: const Text("Confirm Top Up", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Smart Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: user != null ? FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots() : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          double balance = 0.0;
          String firstName = 'User';
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            balance = (data['balance'] ?? 0.0).toDouble();
            firstName = data['firstName'] ?? 'User';
          }

          // Generate card number from UID
          final cardLast4 = user != null ? user.uid.hashCode.abs().toString().padLeft(4, '0').substring(0, 4) : '0000';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Premium Card ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.maroon, const Color(0xFFB8475E), AppTheme.maroon.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: AppTheme.maroon.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("SDBS", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3)),
                              const Text("Smart Card", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Icon(Icons.contactless, color: Colors.white.withValues(alpha: 0.7), size: 32),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "•••• •••• •••• $cardLast4",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18, letterSpacing: 2),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("BALANCE", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(
                                "${balance.toStringAsFixed(2)} JOD",
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("HOLDER", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(firstName.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Quick Top-Up Chips ────────────────────────────────
                const Text("Quick Top Up", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildQuickChip("1 JOD", 1.0),
                    const SizedBox(width: 10),
                    _buildQuickChip("3 JOD", 3.0),
                    const SizedBox(width: 10),
                    _buildQuickChip("5 JOD", 5.0),
                    const SizedBox(width: 10),
                    _buildQuickChip("10 JOD", 10.0),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Custom Amount", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => _showTopUpDialog(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Transaction History ────────────────────────────────
                const Text("Recent Transactions", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (user != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('transactions')
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, txSnap) {
                      if (txSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      if (!txSnap.hasData || txSnap.data!.docs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 40, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text("No transactions yet", style: TextStyle(color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              Text("Your top-ups will appear here.", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            ],
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txSnap.data!.docs.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (context, index) {
                            final tx = txSnap.data!.docs[index].data() as Map<String, dynamic>;
                            final type = tx['type'] ?? 'topup';
                            final amount = (tx['amount'] ?? 0.0).toDouble();
                            final timestamp = tx['timestamp'] as Timestamp?;
                            final timeStr = timestamp != null ? _formatTime(timestamp) : 'Just now';
                            final isTopUp = type == 'topup';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isTopUp ? Colors.green.shade50 : Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isTopUp ? Icons.add : Icons.remove,
                                  color: isTopUp ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                isTopUp ? "Wallet Top Up" : "Payment",
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(timeStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              trailing: Text(
                                "${isTopUp ? '+' : '-'} ${amount.toStringAsFixed(2)} JOD",
                                style: TextStyle(
                                  color: isTopUp ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.maroon,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Cards'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, double amount) {
    return Expanded(
      child: Material(
        color: AppTheme.maroon.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTopUpDialog(presetAmount: amount),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.maroon, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    final d = timestamp.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }
}
