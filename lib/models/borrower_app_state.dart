import 'package:flutter/foundation.dart';

class BorrowerRequest {
  final String bank, loanType, amount, score;
  String status;
  BorrowerRequest({required this.bank, required this.loanType, required this.amount, required this.score, this.status='Pending'});
}

class BorrowerAppState extends ChangeNotifier {
  BorrowerAppState._();
  static final BorrowerAppState instance = BorrowerAppState._();
  String fullName='Borrower', email='', phone='', loanType='Personal Loan';
  double income=0, debts=0, expenses=0, amount=0;
  String selectedBank='Al Rajhi Bank';
  final List<BorrowerRequest> requests=[];
  void register({required String name, required String emailAddress, required String mobile}) { fullName=name.trim(); email=emailAddress.trim(); phone=mobile.trim(); notifyListeners(); }
  void selectLoanType(String value){loanType=value; notifyListeners();}
  void saveAssessment({required double monthlyIncome,required double existingDebts,required double monthlyExpenses,required double desiredAmount}){income=monthlyIncome;debts=existingDebts;expenses=monthlyExpenses;amount=desiredAmount;notifyListeners();}
  void selectBank(String bank){selectedBank=bank;notifyListeners();}
  void submitRequest(){requests.add(BorrowerRequest(bank:selectedBank,loanType:loanType,amount:amount.toStringAsFixed(0),score:'88%'));notifyListeners();}
  int get pending=>requests.where((r)=>r.status=='Pending').length;
}
