import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';
import '../utils/validators.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {

  Future<void> _updateUserRole(String userId, String newRole) async {
    await ErrorHandler.run(
      context,
      () => Provider.of<AuthService>(context, listen: false).updateUserRole(userId, newRole),
      successMessage: 'Role updated to $newRole',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.maroon,
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final String firstName = user['firstName'] ?? '';
              final String lastName = user['lastName'] ?? '';
              final String email = user['email'] ?? '';
              final String currentRole = user['role'] ?? 'Passenger';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.maroon.withValues(alpha: 0.1),
                    child: Icon(
                      currentRole == 'Admin' ? Icons.security :
                      currentRole == 'Driver' ? Icons.directions_bus : Icons.person,
                      color: AppTheme.maroon,
                    ),
                  ),
                  title: Text('$firstName $lastName', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentRole,
                        items: ['Passenger', 'Driver', 'Admin'].map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                        onChanged: (String? newRole) {
                          if (newRole != null && newRole != currentRole) {
                            _updateUserRole(userId, newRole);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController(text: "sdbs1234!");
    String selectedRole = 'Passenger';
    bool isLoadingDialog = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Create New User"),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        decoration: const InputDecoration(labelText: "First Name"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      TextFormField(
                        controller: lastNameController,
                        decoration: const InputDecoration(labelText: "Last Name"),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: "Email"),
                        validator: Validators.email,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: "Phone Number"),
                        keyboardType: TextInputType.phone,
                        validator: Validators.jordanPhone,
                      ),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: "Initial Password"),
                        validator: Validators.password,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(labelText: "Role"),
                        items: ['Passenger', 'Driver', 'Admin']
                            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedRole = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (isLoadingDialog)
                  const CircularProgressIndicator()
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => isLoadingDialog = true);
                      try {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        // Uniqueness check via AuthService
                        if (await authService.emailAlreadyRegistered(emailController.text)) {
                          setStateDialog(() => isLoadingDialog = false);
                          if (context.mounted) {
                            ErrorHandler.showError(context, '❌ This email is already registered!');
                          }
                          return;
                        }
                        // Delegate all creation to AuthService
                        await authService.createUserByAdmin(
                          email: emailController.text,
                          password: passwordController.text,
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                          phone: phoneController.text,
                          role: selectedRole,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ErrorHandler.showSuccess(context, 'User created successfully!');
                        }
                      } catch (e) {
                        setStateDialog(() => isLoadingDialog = false);
                        if (context.mounted) {
                          final msg = e.toString();
                          String friendly;
                          if (msg.contains('email-already-in-use')) {
                            friendly = '❌ This email is already registered!';
                          } else if (msg.contains('weak-password')) {
                            friendly = 'Password is too weak.';
                          } else if (msg.contains('network-request-failed')) {
                            friendly = 'No internet connection.';
                          } else {
                            friendly = 'Failed to create user. Please try again.';
                          }
                          ErrorHandler.showError(context, friendly);
                        }
                      }
                    },
                    child: const Text("Create", style: TextStyle(color: Colors.white)),
                  )
                ]
              ],
            );
          }
        );
      },
    );
  }
}
