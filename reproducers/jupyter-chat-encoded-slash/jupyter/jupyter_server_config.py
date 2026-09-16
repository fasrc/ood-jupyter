c = get_config()  # noqa: F821

c.ServerApp.ip = "0.0.0.0"
c.ServerApp.open_browser = False
c.ServerApp.port = 8888
c.ServerApp.token = ""
c.ServerApp.password = ""
c.ServerApp.root_dir = "/work"
c.ServerApp.allow_remote_access = True
c.ServerApp.trust_xheaders = True
c.ServerApp.disable_check_xsrf = True
c.ServerApp.allow_origin_pat = r"^http://(localhost|127\.0\.0\.1)(:\d+)?$"
c.IdentityProvider.token = ""
