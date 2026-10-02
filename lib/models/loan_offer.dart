class LoanOffer {
  final String id;
  final String lenderId;

  final String bankName;
  final String offerName;
  final String loanType;

  final String interestRate;
  final String term;
  final String amount;

  final String email;

  LoanOffer({
    required this.id,
    required this.lenderId,
    required this.bankName,
    required this.offerName,
    required this.loanType,
    required this.interestRate,
    required this.term,
    required this.amount,
    required this.email,
  });

  factory LoanOffer.fromMap(Map<String, dynamic> map) {
    return LoanOffer(
      id: map['id']?.toString() ?? '',
      lenderId: map['lender_id']?.toString() ?? '',
      bankName: map['bank_name']?.toString() ?? '',
      offerName: map['offer_name']?.toString() ?? '',
      loanType: map['loan_type']?.toString() ?? '',
      interestRate: map['interest_rate']?.toString() ?? '',
      term: map['max_term_months']?.toString() ?? '',
      amount: map['max_amount']?.toString() ?? '',
      email: map['contact_email']?.toString() ?? '',
    );
  }
}
