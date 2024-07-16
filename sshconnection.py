#!/usr/bin/env python3

import fabric


class SSHConnection:
    """High-level SSH operation class"""

    def __init__(
        self,
        host: str,
        user: str,
        password: str,
        connect_timeout: int = 30,
        port: int = 22,
        connect_kwargs=None,
    ):
        self.host = host
        self.user = user
        self.password = password
        self.connect_timeout = connect_timeout
        self.port = port
        if connect_kwargs is None:
            connect_kwargs = {}
        self.connect_kwargs = connect_kwargs
        self.connection = None

    def connect(self):
        connect_kwargs = dict(self.connect_kwargs)
        if self.password:
            connect_kwargs["password"] = self.password
        self.connection = fabric.Connection(
            host=self.host, user=self.user, connect_kwargs=connect_kwargs
        )

    def run_cmd(self, cmd: str, warn=False, echo=False, in_stream=False, timeout=30):
        """See https://docs.pyinvoke.org/en/latest/api/runners.html#invoke.runners.Runner.run
        for meaning of arguments to `run_cmd`.
        """
        if not self.connection:
            self.connect()
        result = self.connection.run(
            cmd, warn=warn, echo=echo, in_stream=in_stream, timeout=timeout
        )
        return result
