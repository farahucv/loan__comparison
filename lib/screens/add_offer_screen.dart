import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/loan_offer.dart';
import '../services/loan_offer_service.dart';

class AddOfferScreen extends StatefulWidget {
  final LoanOffer? existingOffer;

  const AddOfferScreen({super.key, this.existingOffer});

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final _formKey = GlobalKey<FormState>();

  final LoanOfferService _offerService = LoanOfferService();

  bool isSaving = false;

  String? selectedLoanType;

  final List<String> loanTypes = [
    "Personal Loan",
    "Business Loan",
    "Investment Loan",
  ];

  final offerNameController = TextEditingController();
  final rateController = TextEditingController();
  final termController = TextEditingController();
  final amountController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.existingOffer != null) {
      final offer = widget.existingOffer!;

      
      offerNameController.text = offer.offerName;
      rateController.text = offer.interestRate;
      termController.text = offer.term;
      amountController.text = offer.amount;
      emailController.text = offer.email;

      selectedLoanType = loanTypes.contains(offer.loanType)
          ? offer.loanType
          : null;
    }
  }

  @override
  void dispose() {
    
    offerNameController.dispose();
    rateController.dispose();
    termController.dispose();
    amountController.dispose();
    emailController.dispose();

    super.dispose();
  }

  Future<void> _saveOffer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rate = double.tryParse(rateController.text.trim());

    final term = int.tryParse(termController.text.trim());

    final amount = double.tryParse(amountController.text.trim());

    if (rate == null || rate < 0) {
      _showError('Please enter a valid interest rate.');
      return;
    }

    if (term == null || term <= 0) {
      _showError('Please enter a valid repayment term.');
      return;
    }

    if (amount == null || amount <= 0) {
      _showError('Please enter a valid maximum amount.');
      return;
    }

    if (selectedLoanType == null) {
      _showError('Please select a loan type.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      LoanOffer savedOffer;

      if (widget.existingOffer == null) {
        savedOffer = await _offerService.addOffer(
          bankName: "",
          offerName: offerNameController.text.trim(),
          loanType: selectedLoanType!,
          interestRate: rate,
          term: term,
          amount: amount,
          email: emailController.text.trim(),
        );
      } else {
        savedOffer = await _offerService.updateOffer(
          id: widget.existingOffer!.id,
bankName: widget.existingOffer?.bankName ?? "",          offerName: offerNameController.text.trim(),
          loanType: selectedLoanType!,
          interestRate: rate,
          term: term,
          amount: amount,
          email: emailController.text.trim(),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingOffer == null
                ? 'Offer created successfully.'
                : 'Offer updated successfully.',
          ),
        ),
      );

      Navigator.pop(context, savedOffer);
    } catch (error) {
      if (!mounted) return;

      _showError('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppPalette.bg1, AppPalette.bg2, AppPalette.bg3],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      widget.existingOffer == null
                          ? "Add New Loan Offer"
                          : "Edit Loan Offer",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 25),

                    inputField(
  "Offer Name",
  offerNameController,
),

                    AppText(
                      "Loan Type",
                      style: const TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: selectedLoanType,
                      dropdownColor: AppPalette.bg2,
                      decoration: inputDecoration(),
                      items: loanTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: AppText(
                            type,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedLoanType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return "Please select loan type";
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    inputField(
                      "Interest Rate (%)",
                      rateController,
                      number: true,
                    ),

                    inputField(
                      "Max Term (Months)",
                      termController,
                      number: true,
                    ),

                    inputField(
                      "Maximum Amount (SAR)",
                      amountController,
                      number: true,
                    ),

                    inputField("Contact Email", emailController, email: true),

                    const SizedBox(height: 25),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              onPressed: isSaving ? null : _saveOffer,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : AppText(
                                      widget.existingOffer == null
                                          ? "Create Offer"
                                          : "Save Changes",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.12),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                              child: AppText(
                                "Cancel",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget inputField(
    String hint,
    TextEditingController controller, {
    bool number = false,
    bool email = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : email
            ? TextInputType.emailAddress
            : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "This field is required";
          }

          if (email && !value.contains('@')) {
            return "Enter a valid email";
          }

          return null;
        },
        decoration: inputDecoration().copyWith(hintText: hint),
      ),
    );
  }

  InputDecoration inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Colors.white60),
    );
  }
}
