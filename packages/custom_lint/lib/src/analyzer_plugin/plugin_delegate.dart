import 'dart:io';

import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
// ignore: implementation_imports
import 'package:analyzer_plugin/src/protocol/protocol_internal.dart' as plugin
    show RequestParams;
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'server_plugin.dart';

/// Informations about a plugin
class PluginDetails {
  /// Informations about a plugin
  PluginDetails({
    required this.name,
    required this.root,
    required this.contextRoots,
  });

  /// The unique key of the plugin
  final Uri root;

  /// The name of the plugin
  final String name;

  /// The list of context roots where this plugin is enabled.
  final List<plugin.ContextRoot> contextRoots;
}

/// A delegate for handling certain events based on the platform
abstract class CustomLintDelegate {
  /// The server threw an error
  void serverError(
    ServerPlugin serverPlugin,
    List<plugin.ContextRoot> contextRoots,
    Object error,
    StackTrace stackTrace,
  );

  /// A plugin failed to start
  void pluginInitializationFail(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    Object err,
    StackTrace stackTrace,
  );

  /// A plugin emitted a message
  void pluginMessage(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    String message,
  );

  /// A plugin threw outside of a request
  void pluginError(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    String err,
    String stackTrace,
  );

  /// A plugin threw during a request
  void requestError(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    plugin.RequestParams request,
    plugin.RequestError requestError,
  );
}

/// Sends the output of some events into a log file
mixin LogCustomLintDelegate implements CustomLintDelegate {
  void _log(
    List<plugin.ContextRoot> contextRoots,
    String message, {
    required String pluginName,
  }) {
    final now = DateTime.now();
    final label = '[$pluginName] ${now.toIso8601String()}';

    final msg = message
        .split('\n')
        .map((e) => e.isEmpty ? '$label\n' : '$label $e\n')
        .join();

    for (final contextRoot in contextRoots) {
      final file = File(join(contextRoot.root, 'custom_lint.log'));

      file
        ..createSync(recursive: true)
        ..writeAsStringSync(msg, mode: FileMode.append);
    }
  }

  @override
  void serverError(
    ServerPlugin serverPlugin,
    List<plugin.ContextRoot> contextRoots,
    Object error,
    StackTrace stackTrace,
  ) {
    _log(contextRoots, '$error\n$stackTrace', pluginName: 'custom_lint');
  }

  @override
  void pluginInitializationFail(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    Object err,
    StackTrace stackTrace,
  ) {
    _log(
      pluginDetails.contextRoots,
      '$err\n$stackTrace',
      pluginName: pluginDetails.name,
    );
  }

  @override
  @mustCallSuper
  void pluginMessage(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    String message,
  ) {
    _log(
      pluginDetails.contextRoots,
      message,
      pluginName: pluginDetails.name,
    );
  }

  @override
  void requestError(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    plugin.RequestParams request,
    plugin.RequestError requestError,
  ) {
    _log(
      pluginDetails.contextRoots,
      '''
The request ${request.toRequest('42').method} failed with the following error:
${requestError.code}
${requestError.message}
at:
${requestError.stackTrace}
''',
      pluginName: pluginDetails.name,
    );
  }

  @override
  void pluginError(
    ServerPlugin serverPlugin,
    PluginDetails pluginDetails,
    String err,
    String stackTrace,
  ) {
    _log(
      pluginDetails.contextRoots,
      '$err\n$stackTrace',
      pluginName: pluginDetails.name,
    );
  }
}

/// Redirects events to the analyzer server
class AnalyzerPluginCustomLintDelegate
    with LogCustomLintDelegate
    implements CustomLintDelegate {}

/// Maps events to the console
class CommandCustomLintDelegate
    with LogCustomLintDelegate
    implements CustomLintDelegate {}
