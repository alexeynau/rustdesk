import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import './dialog.dart';

const kOpSvgList = [
  'github',
  'gitlab',
  'google',
  'apple',
  'okta',
  'facebook',
  'azure',
  'auth0'
];

class _IconOP extends StatelessWidget {
  final String op;
  final String? icon;
  final EdgeInsets margin;
  const _IconOP(
      {Key? key,
      required this.op,
      required this.icon,
      this.margin = const EdgeInsets.symmetric(horizontal: 4.0)})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final svgFile =
        kOpSvgList.contains(op.toLowerCase()) ? op.toLowerCase() : 'default';
    return Container(
      margin: margin,
      child: icon == null
          ? SvgPicture.asset(
              'assets/auth-$svgFile.svg',
              width: 20,
            )
          : SvgPicture.string(
              icon!,
              width: 20,
            ),
    );
  }
}

class ButtonOP extends StatelessWidget {
  final String op;
  final RxString curOP;
  final String? icon;
  final Color primaryColor;
  final double height;
  final Function() onTap;

  const ButtonOP({
    Key? key,
    required this.op,
    required this.curOP,
    required this.icon,
    required this.primaryColor,
    required this.height,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final opLabel = {
          'github': 'GitHub',
          'gitlab': 'GitLab'
        }[op.toLowerCase()] ??
        toCapitalized(op);
    return Row(children: [
      Container(
        height: height,
        width: 200,
        child: Obx(() => ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: curOP.value.isEmpty || curOP.value == op
                  ? primaryColor
                  : Colors.grey,
            ).copyWith(elevation: ButtonStyleButton.allOrNull(0.0)),
            onPressed: curOP.value.isEmpty || curOP.value == op ? onTap : null,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: _IconOP(
                    op: op,
                    icon: icon,
                    margin: EdgeInsets.only(right: 5),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Center(
                        child: Text('${translate("Continue with")} $opLabel')),
                  ),
                ),
              ],
            ))),
      ),
    ]);
  }
}

class ConfigOP {
  final String op;
  final String? icon;
  ConfigOP({required this.op, required this.icon});
}

class WidgetOP extends StatefulWidget {
  final ConfigOP config;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;
  const WidgetOP({
    Key? key,
    required this.config,
    required this.curOP,
    required this.cbLogin,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _WidgetOPState();
  }
}

class _WidgetOPState extends State<WidgetOP> {
  Timer? _updateTimer;
  String _stateMsg = '';
  String _failedMsg = '';
  String _url = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _updateTimer?.cancel();
  }

  _beginQueryState() {
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateState();
    });
  }

  _updateState() {
    bind.mainAccountAuthResult().then((result) {
      if (result.isEmpty) {
        return;
      }
      final resultMap = jsonDecode(result);
      if (resultMap == null) {
        return;
      }
      final String stateMsg = resultMap['state_msg'];
      String failedMsg = resultMap['failed_msg'];
      final String? url = resultMap['url'];
      final authBody = resultMap['auth_body'];
      if (_stateMsg != stateMsg || _failedMsg != failedMsg) {
        if (_url.isEmpty && url != null && url.isNotEmpty) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          _url = url;
        }
        if (authBody != null) {
          _updateTimer?.cancel();
          widget.curOP.value = '';
          widget.cbLogin(authBody as Map<String, dynamic>);
        }

        setState(() {
          _stateMsg = stateMsg;
          _failedMsg = failedMsg;
          if (failedMsg.isNotEmpty) {
            widget.curOP.value = '';
            _updateTimer?.cancel();
          }
        });
      }
    });
  }

  _resetState() {
    _stateMsg = '';
    _failedMsg = '';
    _url = '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonOP(
          op: widget.config.op,
          curOP: widget.curOP,
          icon: widget.config.icon,
          primaryColor: str2color(widget.config.op, 0x7f),
          height: 36,
          onTap: () async {
            _resetState();
            widget.curOP.value = widget.config.op;
            await bind.mainAccountAuth(op: widget.config.op, rememberMe: true);
            _beginQueryState();
          },
        ),
        Obx(() {
          if (widget.curOP.isNotEmpty &&
              widget.curOP.value != widget.config.op) {
            _failedMsg = '';
          }
          return Offstage(
            offstage:
                _failedMsg.isEmpty && widget.curOP.value != widget.config.op,
            child: RichText(
              text: TextSpan(
                text: '$_stateMsg  ',
                style:
                    DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
                children: <TextSpan>[
                  TextSpan(
                    text: _failedMsg,
                    style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 14,
                          color: Colors.red,
                        ),
                  ),
                ],
              ),
            ),
          );
        }),
        Obx(
          () => Offstage(
            offstage: widget.curOP.value != widget.config.op,
            child: const SizedBox(
              height: 5.0,
            ),
          ),
        ),
        Obx(
          () => Offstage(
            offstage: widget.curOP.value != widget.config.op,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 20),
              child: ElevatedButton(
                onPressed: () {
                  widget.curOP.value = '';
                  _updateTimer?.cancel();
                  _resetState();
                  bind.mainAccountAuthCancel();
                },
                child: Text(
                  translate('Cancel'),
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoginWidgetOP extends StatelessWidget {
  final List<ConfigOP> ops;
  final RxString curOP;
  final Function(Map<String, dynamic>) cbLogin;

  LoginWidgetOP({
    Key? key,
    required this.ops,
    required this.curOP,
    required this.cbLogin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var children = ops
        .map((op) => [
              WidgetOP(
                config: op,
                curOP: curOP,
                cbLogin: cbLogin,
              ),
              const Divider(
                indent: 5,
                endIndent: 5,
              )
            ])
        .expand((i) => i)
        .toList();
    if (children.isNotEmpty) {
      children.removeLast();
    }
    return SingleChildScrollView(
        child: Container(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            )));
  }
}

class LoginWidgetUserPass extends StatelessWidget {
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController phoneNumber;
  final TextEditingController phoneNumberCode;
  final String? emailMsg;
  final String? passMsg;
  final String? phoneNumberMsg;
  final String? phoneNumberCodeMsg;
  final bool isInProgress;
  final RxString curOP;
  final Function() onLogin;
  final FocusNode? userFocusNode;
  const LoginWidgetUserPass({
    Key? key,
    this.userFocusNode,
    required this.email,
    required this.pass,
    required this.emailMsg,
    required this.passMsg,
    required this.isInProgress,
    required this.curOP,
    required this.onLogin,
    required this.phoneNumber,
    required this.phoneNumberCode,
    required this.phoneNumberMsg,
    required this.phoneNumberCodeMsg,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8.0),
            DialogTextField(
                title: translate(DialogTextField.kEmailTitle),
                controller: email,
                focusNode: userFocusNode,
                prefixIcon: DialogTextField.kEmailIcon,
                errorText: emailMsg),
            PhoneNumberWidget(
              phoneNumberController: phoneNumber,
              phoneNumberMsg: phoneNumberMsg,
              codeController: phoneNumberCode,
              codeMsg: phoneNumberCodeMsg,
            ),
            PasswordWidget(
              controller: pass,
              autoFocus: false,
              errorText: passMsg,
            ),

            // NOT use Offstage to wrap LinearProgressIndicator
            if (isInProgress) const LinearProgressIndicator(),
            const SizedBox(height: 12.0),
            FittedBox(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                height: 38,
                width: 200,
                child: Obx(() => ElevatedButton(
                      child: Text(
                        translate('Login'),
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed:
                          curOP.value.isEmpty || curOP.value == 'rustdesk'
                              ? () {
                                  onLogin();
                                }
                              : null,
                    )),
              ),
            ])),
          ],
        ));
  }

  Row PhoneWidget() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DialogTextField(
              title: 'Code',
              controller: phoneNumberCode,
              prefixIcon: Icon(Icons.add),
              errorText: phoneNumberCodeMsg),
        ),
        SizedBox(
          width: 8,
        ),
        Expanded(
          flex: 5,
          child: DialogTextField(
              title: DialogTextField.kPhoneNumberTitle,
              controller: phoneNumber,
              prefixIcon: DialogTextField.kPhoneNumberIcon,
              errorText: phoneNumberMsg),
        ),
      ],
    );
  }
}

const kAuthReqTypeOidc = 'oidc/';

/// common login dialog for desktop
/// call this directly
Future<bool?> loginDialog() async {
  var email = TextEditingController();
  var password = TextEditingController();
  var phoneNumber = TextEditingController();
  var phoneNumberCode = TextEditingController();
  final userFocusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => userFocusNode..requestFocus());

  String? emailMsg;
  String? passwordMsg;
  String? phoneNumberMsg;
  String? phoneNumberCodeMsg;
  var isInProgress = false;
  final RxString curOP = ''.obs;

  // final loginOptions = [].obs;
  // Future.delayed(Duration.zero, () async {
  //   loginOptions.value = await UserModel.queryOidcLoginOptions();
  // });

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    email.addListener(() {
      if (emailMsg != null) {
        setState(() => emailMsg = null);
      }
    });

    password.addListener(() {
      if (passwordMsg != null) {
        setState(() => passwordMsg = null);
      }
    });

    phoneNumber.addListener(() {
      if (phoneNumberMsg != null) {
        setState(() => phoneNumberMsg = null);
      }
    });

    phoneNumberCode.addListener(() {
      if (phoneNumberCodeMsg != null) {
        setState(() => phoneNumberCodeMsg = null);
      }
    });

    onDialogCancel() {
      isInProgress = false;
      close(false);
    }

    onLogin() async {
      // validate
      if (email.text.isEmpty) {
        setState(() => emailMsg = translate('Username missed'));
        return;
      }
      if (password.text.isEmpty) {
        setState(() => passwordMsg = translate('Password missed'));
        return;
      }
      if (phoneNumber.text.isEmpty) {
        setState(() => phoneNumberMsg = 'Phone number missed');
        return;
      }
      if (phoneNumberCode.text.isEmpty) {
        setState(() => phoneNumberCodeMsg = 'Phone number code missed');
        return;
      }
      curOP.value = 'rustdesk';
      setState(() => isInProgress = true);
      try {
        final resp = await gFFI.userModel.myLogin(MyLoginRequest(
          email: email.text,
          password: password.text,
          phoneNumber: phoneNumber.text,
          phoneNumberCode: phoneNumberCode.text,
        ));
        switch (resp.type) {
          case HttpType.kAuthResTypeToken:
            if (resp.access_token != null) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              // await bind.mainSetLocalOption(
              //     key: 'user_info', value: jsonEncode(resp.user ?? {}));
              close(true);
              return;
            }
            break;
          // case HttpType.kAuthResTypeEmailCheck:
          //   if (isMobile) {
          //     close(true);
          //     verificationCodeDialog(resp.user);
          //   } else {
          //     setState(() => isInProgress = false);
          //     final res = await verificationCodeDialog(resp.user);
          //     if (res == true) {
          //       close(true);
          //       return;
          //     }
          //   }
          //   break;
          default:
            passwordMsg = "Failed, bad response from server";
            break;
        }
      } on RequestException catch (err) {
        passwordMsg = translate(err.cause);
      } catch (err) {
        passwordMsg = "Unknown Error: $err";
      }
      curOP.value = '';
      setState(() => isInProgress = false);
    }

    // thirdAuthWidget() => Obx(() {
    //       return Offstage(
    //         offstage: loginOptions.isEmpty,
    //         child: Column(
    //           children: [
    //             const SizedBox(
    //               height: 8.0,
    //             ),
    //             Center(
    //                 child: Text(
    //               translate('or'),
    //               style: TextStyle(fontSize: 16),
    //             )),
    //             const SizedBox(
    //               height: 8.0,
    //             ),
    //             LoginWidgetOP(
    //               ops: loginOptions
    //                   .map((e) => ConfigOP(op: e['name'], icon: e['icon']))
    //                   .toList(),
    //               curOP: curOP,
    //               cbLogin: (Map<String, dynamic> authBody) {
    //                 try {
    //                   // access_token is already stored in the rust side.
    //                   gFFI.userModel.getLoginResponseFromAuthBody(authBody);
    //                 } catch (e) {
    //                   debugPrint(
    //                       'Failed to parse oidc login body: "$authBody"');
    //                 }
    //                 close(true);
    //               },
    //             ),
    //           ],
    //         ),
    //       );
    //     });

    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('Login'),
        ).marginOnly(top: MyTheme.dialogPadding),
        InkWell(
          child: Icon(
            Icons.close,
            size: 25,
            // No need to handle the branch of null.
            // Because we can ensure the color is not null when debug.
            color: Theme.of(context)
                .textTheme
                .titleLarge
                ?.color
                ?.withOpacity(0.55),
          ),
          onTap: onDialogCancel,
          hoverColor: Colors.red,
          borderRadius: BorderRadius.circular(5),
        ).marginOnly(top: 10, right: 15),
      ],
    );
    final titlePadding = EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0);

    return CustomAlertDialog(
      title: title,
      titlePadding: titlePadding,
      contentBoxConstraints: BoxConstraints(minWidth: 400),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            height: 8.0,
          ),
          LoginWidgetUserPass(
            email: email,
            pass: password,
            emailMsg: emailMsg,
            passMsg: passwordMsg,
            phoneNumber: phoneNumber,
            phoneNumberCode: phoneNumberCode,
            phoneNumberMsg: phoneNumberMsg,
            phoneNumberCodeMsg: phoneNumberCodeMsg,
            isInProgress: isInProgress,
            curOP: curOP,
            onLogin: onLogin,
            userFocusNode: userFocusNode,
          ),
          // thirdAuthWidget(),
        ],
      ),
      onCancel: onDialogCancel,
    );
  });

  if (res != null) {
    await UserModel.updateOtherModels();
  }

  return res;
}

Future<bool?> signUpDialog() async {
  var name = TextEditingController();
  var password = TextEditingController();
  var email = TextEditingController();
  var confirmPassword = TextEditingController();
  var phoneNumber = TextEditingController();
  var phoneNumberCode = TextEditingController();

  final userFocusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => userFocusNode..requestFocus());

  String? usernameMsg;
  String? passwordMsg;
  String? phoneNumberMsg;
  String? phoneNumberCodeMsg;
  String? emailMsg;

  var isInProgress = false;
  final RxString curOP = ''.obs;

  // final signUpOptions = [].obs;
  // Future.delayed(Duration.zero, () async {
  //   signUpOptions.value = await UserModel.queryOidcLoginOptions();
  // });

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    // TODO: make it shorter
    name.addListener(() {
      if (usernameMsg != null) {
        setState(() => usernameMsg = null);
      }
    });

    password.addListener(() {
      if (passwordMsg != null) {
        setState(() => passwordMsg = null);
      }
    });
    phoneNumber.addListener(() {
      if (phoneNumberMsg != null) {
        setState(() => phoneNumberMsg = null);
      }
    });
    phoneNumberCode.addListener(() {
      if (phoneNumberCodeMsg != null) {
        setState(() => phoneNumberCodeMsg = null);
      }
    });
    email.addListener(() {
      if (emailMsg != null) {
        setState(() => emailMsg = null);
      }
    });

    onDialogCancel() {
      isInProgress = false;
      close(false);
    }

    onSignUp() async {
      // validate
      if (name.text.isEmpty) {
        setState(() => usernameMsg = translate('Username missed'));
        return;
      }
      if (password.text.isEmpty) {
        setState(() => passwordMsg = translate('Password missed'));
        return;
      }
      if (phoneNumberCode.text.isEmpty) {
        setState(
            () => phoneNumberCodeMsg = translate('Phone number code missed'));
        return;
      }
      if (phoneNumber.text.isEmpty) {
        setState(() => phoneNumberMsg = translate('Phone number missed'));
        return;
      }
      if (email.text.isEmpty) {
        setState(() => emailMsg = translate('Email missed'));
        return;
      }
      if (confirmPassword.text != password.text) {
        setState(() => passwordMsg = translate('Passwords are different'));
        return;
      }
      curOP.value = 'rustdesk';
      setState(() => isInProgress = true);
      try {
        final resp = await gFFI.userModel.signUp(SignUpRequest(
          name: name.text,
          password: password.text,
          email: email.text,
          phone_num: phoneNumber.text,
          phone_num_code: phoneNumberCode.text,
        ));

        switch (resp.type) {
          case HttpType.kAuthResTypeToken:
            if (resp.access_token != null) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              await bind.mainSetLocalOption(
                  key: 'user_info', value: jsonEncode(resp.user ?? {}));
              close(true);
              return;
            }
            break;
          case HttpType.kAuthResTypeEmailCheck:
            if (isMobile) {
              close(true);
              verificationCodeDialog(resp.user);
            } else {
              setState(() => isInProgress = false);
              final res = await verificationCodeDialog(resp.user);
              if (res == true) {
                close(true);
                return;
              }
            }
            break;
          default:
            passwordMsg = "Failed, bad response from server";
            break;
        }
      } on RequestException catch (err) {
        passwordMsg = translate(err.cause);
      } catch (err) {
        passwordMsg = "Unknown Error: $err";
      }
      curOP.value = '';
      setState(() => isInProgress = false);
    }

/*
    thirdAuthWidget() => Obx(() {
          return Offstage(
            offstage: signUpOptions.isEmpty,
            child: Column(
              children: [
                const SizedBox(
                  height: 8.0,
                ),
                Center(
                    child: Text(
                  translate('or'),
                  style: TextStyle(fontSize: 16),
                )),
                const SizedBox(
                  height: 8.0,
                ),
                LoginWidgetOP(
                  ops: loginOptions
                      .map((e) => ConfigOP(op: e['name'], icon: e['icon']))
                      .toList(),
                  curOP: curOP,
                  cbLogin: (Map<String, dynamic> authBody) {
                    try {
                      // access_token is already stored in the rust side.
                      gFFI.userModel.getLoginResponseFromAuthBody(authBody);
                    } catch (e) {
                      debugPrint(
                          'Failed to parse oidc login body: "$authBody"');
                    }
                    close(true);
                  },
                ),
              ],
            ),
          );
        });
*/
    final title = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translate('Sign Up'),
        ).marginOnly(top: MyTheme.dialogPadding),
        InkWell(
          child: Icon(
            Icons.close,
            size: 25,
            // No need to handle the branch of null.
            // Because we can ensure the color is not null when debug.
            color: Theme.of(context)
                .textTheme
                .titleLarge
                ?.color
                ?.withOpacity(0.55),
          ),
          onTap: onDialogCancel,
          hoverColor: Colors.red,
          borderRadius: BorderRadius.circular(5),
        ).marginOnly(top: 10, right: 15),
      ],
    );
    final titlePadding = EdgeInsets.fromLTRB(MyTheme.dialogPadding, 0, 0, 0);

    return CustomAlertDialog(
      title: title,
      titlePadding: titlePadding,
      contentBoxConstraints: BoxConstraints(minWidth: 400),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            height: 8.0,
          ),
          SignUpWidgetUserPass(
            name: name,
            pass: password,
            confirmPassword: confirmPassword,
            email: email,
            phoneNumber: phoneNumber,
            phoneNumberMsg: phoneNumberMsg,
            phoneNumberCodeMsg: phoneNumberCodeMsg,
            phoneNumberCode: phoneNumberCode,
            usernameMsg: usernameMsg,
            emailMsg: emailMsg,
            passMsg: passwordMsg,
            isInProgress: isInProgress,
            curOP: curOP,
            onSignUp: onSignUp,
            userFocusNode: userFocusNode,
          ),
          // thirdAuthWidget(),
        ],
      ),
      onCancel: onDialogCancel,
    );
  });

  if (res != null) {
    await UserModel.updateOtherModels();
  }

  return res;
}

Future<bool?> verificationCodeDialog(UserPayload? user) async {
  var autoLogin = true;
  var isInProgress = false;
  String? errorText;

  final code = TextEditingController();
  final focusNode = FocusNode()..requestFocus();
  Timer(Duration(milliseconds: 100), () => focusNode..requestFocus());

  final res = await gFFI.dialogManager.show<bool>((setState, close, context) {
    bool validate() {
      return code.text.length >= 6;
    }

    code.addListener(() {
      if (errorText != null) {
        setState(() => errorText = null);
      }
    });

    void onVerify() async {
      if (!validate()) {
        setState(
            () => errorText = translate('Too short, at least 6 characters.'));
        return;
      }
      setState(() => isInProgress = true);

      try {
        final resp = await gFFI.userModel.login(LoginRequest(
            verificationCode: code.text,
            email: user?.name,
            id: await bind.mainGetMyId(),
            uuid: await bind.mainGetUuid(),
            autoLogin: autoLogin,
            type: HttpType.kAuthReqTypeEmailCode));

        switch (resp.type) {
          case HttpType.kAuthResTypeToken:
            if (resp.access_token != null) {
              await bind.mainSetLocalOption(
                  key: 'access_token', value: resp.access_token!);
              close(true);
              return;
            }
            break;
          default:
            errorText = "Failed, bad response from server";
            break;
        }
      } on RequestException catch (err) {
        errorText = translate(err.cause);
      } catch (err) {
        errorText = "Unknown Error: $err";
      }

      setState(() => isInProgress = false);
    }

    return CustomAlertDialog(
        title: Text(translate("Verification code")),
        contentBoxConstraints: BoxConstraints(maxWidth: 300),
        content: Column(
          children: [
            Offstage(
                offstage: user?.email == null,
                child: TextField(
                  decoration: InputDecoration(
                      labelText: "Email", prefixIcon: Icon(Icons.email)),
                  readOnly: true,
                  controller: TextEditingController(text: user?.email),
                )),
            const SizedBox(height: 8),
            DialogTextField(
              title: '${translate("Verification code")}:',
              controller: code,
              errorText: errorText,
              focusNode: focusNode,
              helperText: translate('verification_tip'),
            ),
            /*
            CheckboxListTile(
              contentPadding: const EdgeInsets.all(0),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Row(children: [
                Expanded(child: Text(translate("Trust this device")))
              ]),
              value: trustThisDevice,
              onChanged: (v) {
                if (v == null) return;
                setState(() => trustThisDevice = !trustThisDevice);
              },
            ),
            */
            // NOT use Offstage to wrap LinearProgressIndicator
            if (isInProgress) const LinearProgressIndicator(),
          ],
        ),
        onCancel: close,
        onSubmit: onVerify,
        actions: [
          dialogButton("Cancel", onPressed: close, isOutline: true),
          dialogButton("Verify", onPressed: onVerify),
        ]);
  });

  return res;
}

class SignUpWidgetUserPass extends StatelessWidget {
  final TextEditingController name;
  final TextEditingController pass;
  final TextEditingController confirmPassword;
  final TextEditingController email;
  final TextEditingController phoneNumberCode;
  final TextEditingController phoneNumber;
  final String? usernameMsg;
  final String? passMsg;
  final String? emailMsg;
  final String? phoneNumberMsg;
  final String? phoneNumberCodeMsg;
  final bool isInProgress;
  final RxString curOP;
  final Function() onSignUp;
  final FocusNode? userFocusNode;
  const SignUpWidgetUserPass({
    Key? key,
    this.userFocusNode,
    required this.name,
    required this.confirmPassword,
    required this.email,
    required this.phoneNumberCode,
    required this.phoneNumber,
    required this.pass,
    required this.usernameMsg,
    required this.passMsg,
    required this.isInProgress,
    required this.curOP,
    required this.onSignUp,
    this.emailMsg,
    this.phoneNumberMsg,
    this.phoneNumberCodeMsg,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8.0),
            DialogTextField(
                title: translate(DialogTextField.kUsernameTitle),
                controller: name,
                // focusNode: userFocusNode,
                prefixIcon: DialogTextField.kUsernameIcon,
                errorText: usernameMsg),

            DialogTextField(
                title: translate(DialogTextField.kEmailTitle),
                controller: email,
                // focusNode: userFocusNode,
                prefixIcon: DialogTextField.kEmailIcon,
                errorText: emailMsg),

            PhoneNumberWidget(
              phoneNumberController: phoneNumber,
              phoneNumberMsg: phoneNumberMsg,
              codeController: phoneNumberCode,
              codeMsg: phoneNumberCodeMsg,
            ),

            PasswordWidget(
              controller: pass,
              autoFocus: false,
              errorText: passMsg,
            ),
            PasswordWidget(
              controller: confirmPassword,
              autoFocus: false,
              hintText: DialogTextField.kPasswordConfirm,
              errorText: passMsg,
            ),
            // NOT use Offstage to wrap LinearProgressIndicator
            if (isInProgress) const LinearProgressIndicator(),
            const SizedBox(height: 12.0),
            FittedBox(
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                height: 38,
                width: 200,
                child: Obx(() => ElevatedButton(
                      child: Text(
                        translate('Register'),
                        style: TextStyle(fontSize: 16),
                      ),
                      onPressed:
                          curOP.value.isEmpty || curOP.value == 'rustdesk'
                              ? () {
                                  onSignUp();
                                }
                              : null,
                    )),
              ),
            ])),
          ],
        ));
  }
}

void logOutConfirmDialog() {
  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      close();
      gFFI.userModel.logOut();
    }

    return CustomAlertDialog(
      content: Text(translate("logout_tip")),
      actions: [
        dialogButton(translate("Cancel"), onPressed: close, isOutline: true),
        dialogButton(translate("OK"), onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}
