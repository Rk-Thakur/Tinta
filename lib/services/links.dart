import 'package:flutter/services.dart';

/// Where "Buy me a coffee" in Settings goes.
const buyMeACoffeeUrl = 'https://buymeacoffee.com/tinta';

/// Opens an https link in the browser. Whether it opened.
Future<bool> openLink(String url) async {
  try {
    return await const MethodChannel('tinta/device')
            .invokeMethod<bool>('openUrl', {'url': url}) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
