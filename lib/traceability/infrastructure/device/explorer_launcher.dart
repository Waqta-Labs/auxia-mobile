import 'package:url_launcher/url_launcher.dart';

/// Opens a transaction of the delivery in the Sepolia block explorer, where
/// anyone can check the anchored hash (Backend/ENDPOINTS.md).
class ExplorerLauncher {
  Future<void> openTransaction(String transactionHash) async {
    final url = Uri.https('sepolia.etherscan.io', '/tx/$transactionHash');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Exception {
      // Nothing to do: the hash is on the screen to check it elsewhere.
    }
  }
}
