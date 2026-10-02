import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings.dart';
import '../models/loan_offer.dart';
import '../services/loan_offer_service.dart';

import 'add_offer_screen.dart';
import 'home_screen.dart';
import 'review_requests_screen.dart';

class ManageOffersScreen extends StatefulWidget {
  final List<LoanOffer> offers;

  const ManageOffersScreen({super.key, this.offers = const []});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  final LoanOfferService _offerService = LoanOfferService();

  List<LoanOffer> _currentOffers = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _currentOffers = List.from(widget.offers);

    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await _offerService.getMyOffers();

      if (!mounted) return;

      setState(() {
        _currentOffers = offers;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading offers: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteOffer(int index) async {
    final offerToDelete = _currentOffers[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Offer'),
          content: Text(
            'Are you sure you want to delete "${offerToDelete.offerName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _offerService.deleteOffer(offerToDelete.id);

      if (!mounted) return;

      setState(() {
        _currentOffers.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Offer '${offerToDelete.offerName}' deleted")),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting offer: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _editOffer(int index) async {
    final updatedOffer = await Navigator.push<LoanOffer>(
      context,
      MaterialPageRoute(
        builder: (_) => AddOfferScreen(existingOffer: _currentOffers[index]),
      ),
    );

    if (updatedOffer != null) {
      await _loadOffers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/rushd_log.png',
                      width: 180,
                      errorBuilder: (context, error, stackTrace) {
                        return AppText(
                          'Rushd',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),

                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: _navItem("Home"),
                        ),

                        const SizedBox(width: 35),

                        _navItem("Manage Offers", active: true),

                        const SizedBox(width: 35),

                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReviewRequestsScreen(),
                              ),
                            );
                          },
                          child: _navItem("Review Requests"),
                        ),
                      ],
                    ),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _signOut,
                      child: AppText(
                        "Sign Out",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.pop(context, _currentOffers);
                            },
                          ),

                          const SizedBox(width: 10),

                          AppText(
                            "Manage Offers",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Spacer(),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                            ),
                            onPressed: () async {
                              final result = await Navigator.push<LoanOffer>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AddOfferScreen(),
                                ),
                              );

                              if (result != null) {
                                await _loadOffers();
                              }
                            },
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Add Offer',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _currentOffers.isEmpty
                            ? Center(
                                child: AppText(
                                  "No offers available.",
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _currentOffers.length,
                                itemBuilder: (context, index) {
                                  final offer = _currentOffers[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 15),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              AppText(
                                                offer.offerName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              const SizedBox(height: 8),

                                              AppText(
                                                "${offer.bankName} • ${offer.amount} SAR • ${offer.loanType}",
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13,
                                                ),
                                              ),

                                              const SizedBox(height: 4),

                                              AppText(
                                                "Rate: ${offer.interestRate}% • Term: ${offer.term} months",
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Row(
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.lightBlue,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _editOffer(index),
                                              child: AppText(
                                                "Edit",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 10),

                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _deleteOffer(index),
                                              child: AppText(
                                                "Delete",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String title, {bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          title,
          style: TextStyle(
            color: active ? Colors.lightBlue : Colors.white60,
            fontSize: 14,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),

        if (active)
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 25,
            height: 2,
            color: Colors.lightBlue,
          ),
      ],
    );
  }
}
