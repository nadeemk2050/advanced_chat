import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/expense_service.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';
import 'expense_project_screen.dart';

class ExpenseDashboard extends StatefulWidget {
  final String userName;
  const ExpenseDashboard({super.key, required this.userName});

  @override
  State<ExpenseDashboard> createState() => _ExpenseDashboardState();
}

class _ExpenseDashboardState extends State<ExpenseDashboard> {
  final ExpenseService _service = ExpenseService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildProjectList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ChatTheme.primary.withOpacity(0.1), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACTIVE PROJECTS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, letterSpacing: 2)),
              const Text('Track shared trip and project costs.', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          FloatingActionButton.small(
            heroTag: 'expense_project_add_fab',
            onPressed: _showCreateProjectDialog,
            backgroundColor: ChatTheme.primary,
            child: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList() {
    return StreamBuilder<List<ExpenseProject>>(
      stream: _service.getExpenseProjects(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final projects = snapshot.data!;
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 60, color: Colors.white10),
                const SizedBox(height: 16),
                const Text('NO EXPENSE PROJECTS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text('Create one to start tracking.', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: projects.length,
          itemBuilder: (context, i) {
            final p = projects[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExpenseProjectScreen(project: p, userName: widget.userName))),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ChatTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: ChatTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.folder_shared_rounded, color: ChatTheme.primary),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${p.memberIds.length} AGENTS COLLABORATING', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateProjectDialog() {
    final titleController = TextEditingController();
    final budgetController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        title: Text('GENERATE EXPENSE PROJECT', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(hintText: 'e.g., Dubai Trip 2026', labelText: 'Project Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(hintText: 'e.g., 5000', labelText: 'Budget (Optional)', prefixText: '\$ ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _service.createProject(
                  titleController.text, 
                  budget: double.tryParse(budgetController.text) ?? 0
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('LAUNCH'),
          ),
        ],
      ),
    );
  }
}
