import ctypes as C

pam = C.CDLL('libpam.so.0')
callback_type = C.CFUNCTYPE(C.c_int, C.c_int, C.c_void_p, C.c_void_p, C.c_void_p)

@callback_type
def conversation(count, messages, responses, appdata):
    return 19

class Conversation(C.Structure):
    _fields_ = [('conv', callback_type), ('appdata', C.c_void_p)]

pam.pam_start.argtypes = [C.c_char_p, C.c_char_p, C.POINTER(Conversation), C.POINTER(C.c_void_p)]
pam.pam_set_item.argtypes = [C.c_void_p, C.c_int, C.c_void_p]
pam.pam_acct_mgmt.argtypes = [C.c_void_p, C.c_int]
pam.pam_end.argtypes = [C.c_void_p, C.c_int]
for service in ('login', 'sshd'):
    for user in ('root', 'user1', 'user2', 'user3', 'curator1', 'curator2'):
        handle = C.c_void_p()
        conv = Conversation(conversation, None)
        assert pam.pam_start(service.encode(), user.encode(), C.byref(conv), C.byref(handle)) == 0
        assert pam.pam_set_item(handle, 3, C.c_char_p(b'tty1' if service == 'login' else b'ssh')) == 0
        result = pam.pam_acct_mgmt(handle, 0)
        pam.pam_end(handle, result)
        denied = service == 'login' and user.startswith('curator')
        assert (result != 0) if denied else (result == 0), (service, user, result)
        print(f'PAM {service} {user}: {"denied" if result else "allowed"}')

quality = C.CDLL('libpwquality.so.1')
quality.pwquality_default_settings.restype = C.c_void_p
quality.pwquality_read_config.argtypes = [C.c_void_p, C.c_char_p, C.POINTER(C.c_void_p)]
quality.pwquality_check.argtypes = [C.c_void_p, C.c_char_p, C.c_char_p, C.c_char_p, C.POINTER(C.c_void_p)]
quality.pwquality_free_settings.argtypes = [C.c_void_p]
settings = quality.pwquality_default_settings()
aux = C.c_void_p()
assert quality.pwquality_read_config(settings, None, C.byref(aux)) == 0
assert quality.pwquality_check(settings, b'aB3$dE6&hJ9', None, b'user1', C.byref(aux)) < 0
assert quality.pwquality_check(settings, b'7vQ!2xM#9pR@4tN$6wL%8zK&', None, b'user1', C.byref(aux)) >= 0
quality.pwquality_free_settings(settings)
print('Password quality: 11 characters rejected; strong 24 characters accepted')
