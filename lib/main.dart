@override
void initState() {
  super.initState();

  v2ray = V2ray(
    onStatusChanged: (status) {
      if (!mounted) return;

      final state = status.state
          .toString()
          .toLowerCase()
          .trim();

      final isDisconnected =
          state.endsWith('disconnected');

      final isConnected =
          state.endsWith('connected') &&
          !isDisconnected;

      final isConnecting =
          state.endsWith('connecting');

      setState(() {
        if (isDisconnected) {
          connected = false;
          statusText = 'Disconnected';
        } else if (isConnected) {
          connected = true;
          statusText = 'Connected';
        } else if (isConnecting) {
          connected = false;
          statusText = 'Connecting...';
        } else {
          statusText = state;
        }
      });
    },
  );

  initializeApp();
}