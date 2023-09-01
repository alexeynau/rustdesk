import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:flutter_hbb/models/peer_model.dart';

import '../../models/platform_model.dart';

class HttpType {
  static const kAuthReqTypeAccount = "account";
  static const kAuthReqTypeMobile = "mobile";
  static const kAuthReqTypeSMSCode = "sms_code";
  static const kAuthReqTypeEmailCode = "email_code";

  static const kAuthResTypeToken = "access_token";
  static const kAuthResTypeEmailCheck = "email_check";
}

enum UserStatus { kDisabled, kNormal, kUnverified }

// to-do: The UserPayload does not contain all the fields of the user.
// Is all the fields of the user needed?
class UserPayload {
  String name = '';
  String? email = '';
  String? phoneNumber = '';
  String accessToken = '';
  String note = '';
  UserStatus status;
  bool isAdmin = false;

  UserPayload({
    required this.name,
    required this.accessToken,
    this.email,
    this.phoneNumber,
    this.status = UserStatus.kNormal,
    this.isAdmin = false,
    this.note = '',
  });

  UserPayload.fromJson(Map<String, dynamic> json)
      : name = json['name'] ?? '',
        email = json['email'] ?? '',
        // accessToken = json['access_token'] ?? '',
        note = json['note'] ?? '',
        status = json['status'] == 0
            ? UserStatus.kDisabled
            : json['status'] == -1
                ? UserStatus.kUnverified
                : UserStatus.kNormal,
        isAdmin = json['is_admin'] == true;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'name': name,
      'access_token': accessToken,
      'email': email,
      'phoneNumber': phoneNumber,
      'status': status == UserStatus.kDisabled
          ? 0
          : status == UserStatus.kUnverified
              ? -1
              : 1,
    };
    return map;
  }
}

class PeerPayload {
  String id = '';
  String info = '';
  int? status;
  String user = '';
  String user_name = '';
  String note = '';

  PeerPayload.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        info = json['info'] ?? '',
        status = json['status'],
        user = json['user'] ?? '',
        user_name = json['user_name'] ?? '',
        note = json['note'] ?? '';

  static Peer toPeer(PeerPayload p) {
    return Peer.fromJson({"id": p.id, "username": p.user_name});
  }
}

class LoginRequest {
  String? username;
  String? password;
  String? id;
  String? uuid;
  bool? autoLogin;
  String? type;
  String? verificationCode;
  String? email;
  String? phoneNumber;
  int? phoneNumberCode;

  LoginRequest({
    this.username,
    this.password,
    this.id,
    this.uuid,
    this.autoLogin,
    this.type,
    this.verificationCode,
    this.email,
    this.phoneNumber,
    this.phoneNumberCode,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (password != null) data['password'] = password;
    if (id != null) data['id'] = id;
    if (uuid != null) data['uuid'] = uuid;
    if (autoLogin != null) data['autoLogin'] = autoLogin;
    if (type != null) data['type'] = type;
    if (verificationCode != null) {
      data['verificationCode'] = verificationCode;
    }
    if (email != null) data['email'] = email;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (phoneNumberCode != null) data['phoneNumberCode'] = phoneNumberCode;

    Map<String, dynamic> deviceInfo = {};
    try {
      deviceInfo = jsonDecode(bind.mainGetLoginDeviceInfo());
    } catch (e) {
      debugPrint('Failed to decode get device info: $e');
    }
    data['deviceInfo'] = deviceInfo;
    return data;
  }
}

class MyLoginRequest {
  String? password;
  String? email;
  String? phoneNumber;
  String? phoneNumberCode;

  MyLoginRequest({
    this.email,
    this.password,
    this.phoneNumber,
    this.phoneNumberCode,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (password != null) data['password'] = password;
    if (email != null) data['email'] = email;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (phoneNumberCode != null) data['phone_number_code'] = phoneNumberCode;
    return data;
  }
}

class SignUpRequest {
  String? name;
  String? password;
  String? email;
  String? phone_num;
  String? phone_num_code;
  String? id;
  String? uuid;
  bool? autoLogin;
  String? type;
  String? verificationCode;

  SignUpRequest(
      {this.name,
      this.password,
      this.email,
      this.phone_num,
      this.phone_num_code,
      this.id,
      this.uuid,
      this.autoLogin,
      this.type,
      this.verificationCode});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (password != null) data['password'] = password;
    if (email != null) data['email'] = email;
    if (phone_num != null) data['phone_number'] = phone_num;
    if (phone_num_code != null) data['phone_number_code'] = phone_num_code;
    return data;
  }
}

LoginOrSignUpResponse loginOrSignUpResponseFromJson(String str) =>
    LoginOrSignUpResponse.fromJson(json.decode(str));

String loginOrSignUpResponseToJson(LoginOrSignUpResponse data) =>
    json.encode(data.toJson());

class LoginOrSignUpResponse {
  String? accessToken;
  String? refreshToken;
  String? message;

  LoginOrSignUpResponse({
    this.accessToken,
    this.refreshToken,
    this.message,
  });

  factory LoginOrSignUpResponse.fromJson(Map<String, dynamic> json) =>
      LoginOrSignUpResponse(
        accessToken: json["access_token"],
        refreshToken: json["refresh_token"],
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "access_token": accessToken,
        "refresh_token": refreshToken,
        "message": message,
      };
}

class LoginResponse {
  String? access_token;
  String? type;
  UserPayload? user;

  LoginResponse({this.access_token, this.type, this.user});

  LoginResponse.fromJson(Map<String, dynamic> json) {
    access_token = json['access_token'];
    type = json['type'];
    user = json['user'] != null ? UserPayload.fromJson(json['user']) : null;
  }
}

class RequestException implements Exception {
  int statusCode;
  String cause;
  RequestException(this.statusCode, this.cause);

  @override
  String toString() {
    return "RequestException, statusCode: $statusCode, error: $cause";
  }
}
