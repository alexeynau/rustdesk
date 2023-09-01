import 'dart:async';
import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../common.dart';
import 'model.dart';
import 'platform_model.dart';

bool refreshingUser = false;

class UserModel {
  final RxString userName = ''.obs;
  final RxBool isAdmin = false.obs;
  final RxString email = ''.obs;
  final RxString phoneNumber = ''.obs;
  bool get isLogin => email.isNotEmpty || phoneNumber.isNotEmpty;
  WeakReference<FFI> parent;

  UserModel(this.parent);

  void refreshCurrentUser() async {
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token == '') {
      await updateOtherModels();
      return;
    }
    _updateLocalUserInfo();
    final url = await bind.mainGetApiServer();
    final body = {
      'id': await bind.mainGetMyId(),
      'uuid': await bind.mainGetUuid()
    };
    if (refreshingUser) return;
    try {
      refreshingUser = true;
      final response = await http.post(Uri.parse('$url/api/currentUser'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: json.encode(body));
      refreshingUser = false;
      final status = response.statusCode;
      if (status == 401 || status == 400) {
        reset(clearAbCache: status == 401);
        return;
      }
      final data = json.decode(utf8.decode(response.bodyBytes));
      final error = data['error'];
      if (error != null) {
        throw error;
      }

      final user = UserPayload.fromJson(data);
      _parseAndUpdateUser(user);
    } catch (e) {
      debugPrint('Failed to refreshCurrentUser: $e');
    } finally {
      refreshingUser = false;
      await updateOtherModels();
    }
  }

  static Map<String, dynamic>? getLocalUserInfo() {
    final userInfo = bind.mainGetLocalOption(key: 'user_info');
    if (userInfo == '') {
      return null;
    }
    try {
      return json.decode(userInfo);
    } catch (e) {
      debugPrint('Failed to get local user info "$userInfo": $e');
    }
    return null;
  }

  _updateLocalUserInfo() {
    final userInfo = getLocalUserInfo();
    if (userInfo != null) {
      // TODO FIX: Unhandled Exception: type 'Null' is not a subtype of type 'String'
      userName.value = userInfo['name'] ?? '';
    }
  }

  Future<void> reset({bool clearAbCache = false}) async {
    await bind.mainSetLocalOption(key: 'access_token', value: '');
    await bind.mainSetLocalOption(key: 'user_info', value: '');
    if (clearAbCache) await bind.mainClearAb();
    await gFFI.groupModel.reset();
    userName.value = '';
  }

  _parseAndUpdateUser(UserPayload user) {
    userName.value = user.name;
    isAdmin.value = user.isAdmin;
    email.value = user.email ?? '';
    phoneNumber.value = user.phoneNumber ?? '';
    bind.mainSetLocalOption(key: 'user_info', value: jsonEncode(user.toJson()));
  }

  // update ab and group status
  static Future<void> updateOtherModels() async {
    await Future.wait([gFFI.abModel.pullAb(), gFFI.groupModel.pull()]);
  }

  Future<void> logOut({String? apiServer}) async {
    final tag = gFFI.dialogManager.showLoading(translate('Waiting'));
    try {
      final url = apiServer ?? await bind.mainGetApiServer();
      final authHeaders = getHttpHeaders();
      authHeaders['Content-Type'] = "application/json";
      await http
          .post(Uri.parse('$url/api/logout'),
              body: jsonEncode({
                'id': await bind.mainGetMyId(),
                'uuid': await bind.mainGetUuid(),
              }),
              headers: authHeaders)
          .timeout(Duration(seconds: 2));
    } catch (e) {
      debugPrint("request /api/logout failed: err=$e");
    } finally {
      await reset(clearAbCache: true);
      gFFI.dialogManager.dismissByTag(tag);
    }
  }

// TODO: unify login and sign up
  Future<LoginOrSignUpResponse> myLogin(MyLoginRequest loginRequest) async {
    // TODO: bind with rust like this
    // final url = await bind.mainGetApiServer();
    var url = Uri.parse('https://manuspect.ru/auth/login');
    var headersList = {
      'Accept': '*/*',
      'User-Agent': 'Thunder Client (https://www.thunderclient.com)',
      'Content-Type': 'application/x-www-form-urlencoded'
    };

    var body = loginRequest
        .toJson()
        .map((key, value) => MapEntry<String, String>(key, value.toString()));

    var req = http.Request('POST', url);
    req.headers.addAll(headersList);
    req.bodyFields = body;

    var res = await req.send();
    final resBody = await res.stream.bytesToString();

    // if (res.statusCode >= 200 && res.statusCode < 300) {
    //   BotToast.showText(
    //       contentColor: Colors.green, text: 'HTTP ${res.statusCode}');
    //   print(resBody);
    // } else {
    //   BotToast.showText(
    //       contentColor: Colors.red, text: 'HTTP ${res.statusCode}');
    //   print(res.headers);
    //   print(res.request);
    //   print(res.statusCode);
    //   print(res.reasonPhrase);
    //   // throw RequestException(0, "${res.statusCode}: ${res.reasonPhrase!}");
    // }

    final LoginOrSignUpResponse response;
    try {
      response = LoginOrSignUpResponse.fromJson(jsonDecode(resBody));
    } catch (e) {
      debugPrint("login: jsonDecode LoginResponse failed: ${e.toString()}");
      rethrow;
    }
    if (response.accessToken != null) {
      _parseAndUpdateUser(
        UserPayload(
          accessToken: response.accessToken!,
          name: loginRequest.email ?? 'Undefined',
          email: loginRequest.email,
          phoneNumber:
              ('${loginRequest.phoneNumberCode}${loginRequest.phoneNumber}'),
        ),
      );
    }
    return response;
  }

  Future<LoginOrSignUpResponse> signUp(SignUpRequest signUpRequest) async {
    var headersList = {
      'Accept': '*/*',
      'User-Agent': 'Thunder Client (https://www.thunderclient.com)',
      'Content-Type': 'application/x-www-form-urlencoded'
    };

    var url = Uri.parse('https://manuspect.ru/auth/register');

    var body = signUpRequest
        .toJson()
        .map((key, value) => MapEntry<String, String>(key, value.toString()));

    var req = http.Request('POST', url);
    req.headers.addAll(headersList);
    req.bodyFields = body;

    var res = await req.send();

    final resBody = await res.stream.bytesToString();
    // if (res.statusCode >= 200 && res.statusCode < 300) {
    //   BotToast.showText(
    //       contentColor: Colors.green, text: 'HTTP ${res.statusCode}');
    //   print(resBody);
    // } else {
    //   BotToast.showText(
    //       contentColor: Colors.red, text: 'HTTP ${res.statusCode}');
    //   print(res.reasonPhrase);
    // }

    final LoginOrSignUpResponse response;
    try {
      response = LoginOrSignUpResponse.fromJson(jsonDecode(resBody));
    } catch (e) {
      debugPrint("login: jsonDecode LoginResponse failed: ${e.toString()}");
      rethrow;
    }
    if (response.accessToken != null) {
      _parseAndUpdateUser(
        UserPayload(
          accessToken: response.accessToken!,
          name: signUpRequest.name ?? '',
          email: signUpRequest.email,
          phoneNumber:
              ('${signUpRequest.phone_num_code}${signUpRequest.phone_num}'),
        ),
      );
    }
    return response;
  }

  /// throw [RequestException]
  Future<LoginOrSignUpResponse> login(LoginRequest loginRequest) async {
    final url = await bind.mainGetApiServer();
    final resp = await http.post(Uri.parse('$url/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginRequest.toJson()));

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (e) {
      debugPrint("login: jsonDecode resp body failed: ${e.toString()}");
      if (resp.statusCode != 200) {
        BotToast.showText(
            contentColor: Colors.red, text: 'HTTP ${resp.statusCode}');
      }
      rethrow;
    }
    if (resp.statusCode != 200) {
      throw RequestException(resp.statusCode, body['error'] ?? '');
    }
    if (body['error'] != null) {
      throw RequestException(0, body['error']);
    }

    return getResponseFromAuthBody(body);
  }

  LoginOrSignUpResponse getResponseFromAuthBody(Map<String, dynamic> body) {
    final LoginOrSignUpResponse response;
    try {
      response = LoginOrSignUpResponse.fromJson(body);
    } catch (e) {
      debugPrint("login: jsonDecode LoginResponse failed: ${e.toString()}");
      rethrow;
    }

    _parseAndUpdateUser(
      UserPayload(
        name: response.accessToken!,
        accessToken: response.accessToken!,
      ),
    );

    return response;
  }

  static Future<List<dynamic>> queryOidcLoginOptions() async {
    try {
      final url = await bind.mainGetApiServer();
      if (url.trim().isEmpty) return [];
      final resp = await http.get(Uri.parse('$url/api/login-options'));
      final List<String> ops = [];
      for (final item in jsonDecode(resp.body)) {
        ops.add(item as String);
      }
      for (final item in ops) {
        if (item.startsWith('common-oidc/')) {
          return jsonDecode(item.substring('common-oidc/'.length));
        }
      }
      return ops
          .where((item) => item.startsWith('oidc/'))
          .map((item) => {'name': item.substring('oidc/'.length)})
          .toList();
    } catch (e) {
      debugPrint(
          "queryOidcLoginOptions: jsonDecode resp body failed: ${e.toString()}");
      return [];
    }
  }
}
