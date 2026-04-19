import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense_model.dart';
import '../models/chat_models.dart';
import '../services/expense_service.dart';
import '../theme/app_theme.dart';

class ExpenseProjectScreen extends StatefulWidget {
  final ExpenseProject project;
  final String userName;
  const ExpenseProjectScreen({super.key, required this.project, required this.userName});

  @override
  State<ExpenseProjectScreen> createState() => _ExpenseProjectScreenState();
}

class _ExpenseProjectScreenState extends State<ExpenseProjectScreen> with SingleTickerProviderStateMixin {
  final ExpenseService _service = ExpenseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatTheme.background,
      appBar: AppBar(
        title: Text(widget.project.title.toUpperCase(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          indicatorColor: ChatTheme.primary,
          tabs: const [
            Tab(text: 'LEDGER', icon: Icon(Icons.list_alt_rounded, size: 18)),
            Tab(text: 'SETTLEMENTS', icon: Icon(Icons.handshake_rounded, size: 18)),
            Tab(text: 'INSIGHTS', icon: Icon(Icons.pie_chart_rounded, size: 18)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded), onPressed: _showInviteDialog),
          IconButton(icon: const Icon(Icons.settings_suggest_rounded), onPressed: _showBudgetDialog),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLedgerTab(),
          _buildSettlementsTab(),
          _buildInsightsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense_entry_add_fab',
        onPressed: _showAddEntryBottomSheet,
        backgroundColor: ChatTheme.primary,
        icon: const Icon(Icons.add_card_rounded, color: Colors.black),
        label: const Text('TRANSACTION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLedgerTab() {
    return Column(
      children: [
        _buildSummaryCard(),
        Expanded(child: _buildEntryList()),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return StreamBuilder<List<ExpenseEntry>>(
      stream: _service.getEntries(widget.project.id),
      builder: (context, snapshot) {
        double totalPayments = 0;
        double totalReceipts = 0;
        if (snapshot.hasData) {
          for (var e in snapshot.data!) {
            if (e.type == EntryType.payment) totalPayments += e.amount;
            else totalReceipts += e.amount;
          }
        }
        final balance = totalReceipts - totalPayments;
        final bool isOverBudget = widget.project.budget > 0 && totalPayments > widget.project.budget;

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ChatTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isOverBudget ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
          ),
          child: Column(
            children: [
              if (isOverBudget)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                      SizedBox(width: 8),
                      Text('GATES ALERT: OVER BUDGET!', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              Text('NET BALANCE', style: const TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${balance >= 0 ? "+" : ""}${balance.toStringAsFixed(2)}', 
                  style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: balance >= 0 ? Colors.greenAccent : Colors.redAccent)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('PAYMENTS', totalPayments, Colors.redAccent, Icons.arrow_upward_rounded),
                  _buildMiniStat('RECEIPTS', totalReceipts, Colors.greenAccent, Icons.arrow_downward_rounded),
                  if (widget.project.budget > 0)
                    _buildMiniStat('BUDGET', widget.project.budget, Colors.amberAccent, Icons.account_balance_rounded),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, double val, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(val.toStringAsFixed(0), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
      ],
    );
  }

  Widget _buildEntryList() {
    return StreamBuilder<List<ExpenseEntry>>(
      stream: _service.getEntries(widget.project.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snapshot.data!;
        if (entries.isEmpty) return const Center(child: Text('Log is empty.', style: TextStyle(color: Colors.white24)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            final color = e.type == EntryType.payment ? Colors.redAccent : Colors.greenAccent;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(_getCategoryIcon(e.category), color: color, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('${e.addedByName} • ${DateFormat('MMM dd').format(e.date)}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('${e.type == EntryType.payment ? "-" : "+"}${e.amount}', 
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementsTab() {
    return FutureBuilder<List<Settlement>>(
      future: _service.calculateSettlements(widget.project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final settlements = snapshot.data ?? [];
        if (settlements.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_rounded, size: 60, color: Colors.white10),
                SizedBox(height: 16),
                Text('ALL DEBTS SETTLED', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                Text('The Ambani Debt Matrix is clear.', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: settlements.length,
          itemBuilder: (context, i) {
            final s = settlements[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Row(
                children: [
                  const Icon(Icons.outbox_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        children: [
                          TextSpan(text: s.fromUser, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          const TextSpan(text: ' owes '),
                          TextSpan(text: s.toUser, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  Text('\$${s.amount.toStringAsFixed(2)}', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInsightsTab() {
    return StreamBuilder<Map<ExpenseCategory, double>>(
      stream: _service.getCategoryBreakdown(widget.project.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        
        return Column(
          children: [
            const SizedBox(height: 40),
            Text('AMBANI HEATMAP', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.amberAccent)),
            const Text('Asset distribution across categories.', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 40),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: data.entries.map((e) {
                    return PieChartSectionData(
                      color: _getCategoryColor(e.key),
                      value: e.value,
                      title: e.value > 0 ? '${e.value.toStringAsFixed(0)}' : '',
                      radius: 50,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: ExpenseCategory.values.map((cat) {
                  return ListTile(
                    leading: Icon(_getCategoryIcon(cat), color: _getCategoryColor(cat)),
                    title: Text(cat.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    trailing: Text('\$${data[cat]?.toStringAsFixed(2) ?? "0.00"}', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.travel: return Colors.blueAccent;
      case ExpenseCategory.pettyCash: return Colors.greenAccent;
      case ExpenseCategory.project: return Colors.orangeAccent;
      case ExpenseCategory.other: return Colors.purpleAccent;
    }
  }

  IconData _getCategoryIcon(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.travel: return Icons.flight_takeoff_rounded;
      case ExpenseCategory.pettyCash: return Icons.payments_rounded;
      case ExpenseCategory.project: return Icons.business_center_rounded;
      case ExpenseCategory.other: return Icons.category_rounded;
    }
  }

  void _showAddEntryBottomSheet() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    ExpenseCategory selectedCategory = ExpenseCategory.project;
    EntryType selectedType = EntryType.payment;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ChatTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('NEW TRANSACTION', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: ChatTheme.primary)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: InkWell(onTap: () => setS(() => selectedType = EntryType.payment), child: _buildTypeToggle('PAYMENT', EntryType.payment, selectedType, Colors.redAccent))),
                  const SizedBox(width: 12),
                  Expanded(child: InkWell(onTap: () => setS(() => selectedType = EntryType.receipt), child: _buildTypeToggle('RECEIPT', EntryType.receipt, selectedType, Colors.greenAccent))),
                ],
              ),
              const SizedBox(height: 24),
              TextField(controller: titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ ', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ExpenseCategory.values.map((cat) => ChoiceChip(
                  label: Text(cat.name.toUpperCase(), style: const TextStyle(fontSize: 9)),
                  selected: selectedCategory == cat,
                  onSelected: (val) => setS(() => selectedCategory = cat),
                )).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ChatTheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () async {
                  if (titleController.text.isNotEmpty && amountController.text.isNotEmpty) {
                    await _service.addEntry(
                      projectId: widget.project.id,
                      title: titleController.text,
                      amount: double.tryParse(amountController.text) ?? 0,
                      category: selectedCategory,
                      type: selectedType,
                      userName: widget.userName,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('SUBMIT TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeToggle(String label, EntryType type, EntryType selected, Color color) {
    final isSelected = type == selected;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color : Colors.transparent),
      ),
      child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isSelected ? color : Colors.grey))),
    );
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        title: Text('INVITE COLLABORATORS', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: ChatTheme.primary, fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<UserModel>>(
            stream: _service.getFriends(),
            builder: (context, snap) {
              final friends = snap.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, i) {
                  final isAlreadyMember = widget.project.memberIds.contains(friends[i].uid);
                  return ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(friends[i].photoUrl)),
                    title: Text(friends[i].name, style: const TextStyle(color: Colors.white)),
                    trailing: isAlreadyMember ? const Icon(Icons.check_circle, color: Colors.green) : IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: ChatTheme.primary),
                      onPressed: () { _service.addMember(widget.project.id, friends[i].uid); Navigator.pop(context); },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog() {
    final controller = TextEditingController(text: widget.project.budget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        title: const Text('SET PROJECT BUDGET', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Budget Limit', prefixText: '\$ ', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              _service.updateProjectBudget(widget.project.id, double.tryParse(controller.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
