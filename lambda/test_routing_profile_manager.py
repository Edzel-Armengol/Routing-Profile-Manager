import importlib
import json
import os
import sys
import types
import unittest
from unittest.mock import Mock


PROFILE_ID = "11111111-1111-4111-8111-111111111111"
CONNECT_USER_ID = "22222222-2222-4222-8222-222222222222"
INSTANCE_ID = "33333333-3333-4333-8333-333333333333"
AGENT_ARN = (
    "arn:aws:connect:ap-southeast-2:123456789012:"
    f"instance/{INSTANCE_ID}/agent/{CONNECT_USER_ID}"
)


class FakeClientError(Exception):
    def __init__(self, code):
        self.response = {"Error": {"Code": code}}


class RoutingProfileManagerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["CONNECT_INSTANCE_ID"] = INSTANCE_ID

        cls.connect = Mock()
        boto3_module = types.ModuleType("boto3")
        boto3_module.client = Mock(return_value=cls.connect)
        botocore_module = types.ModuleType("botocore")
        exceptions_module = types.ModuleType("botocore.exceptions")
        exceptions_module.ClientError = FakeClientError
        botocore_module.exceptions = exceptions_module
        sys.modules["boto3"] = boto3_module
        sys.modules["botocore"] = botocore_module
        sys.modules["botocore.exceptions"] = exceptions_module

        sys.path.insert(0, os.path.dirname(__file__))
        cls.module = importlib.import_module("routing_profile_manager")

    def setUp(self):
        self.connect.reset_mock()
        paginator = Mock()
        paginator.paginate.return_value = [{
            "RoutingProfileSummaryList": [{
                "Id": PROFILE_ID,
                "Name": "Test profile",
                "Arn": "unused",
            }]
        }]
        self.connect.get_paginator.return_value = paginator

    def event(self, method, path, body=None):
        return {
            "requestContext": {
                "http": {"method": method, "sourceIp": "192.0.2.10"},
            },
            "rawPath": path,
            "body": json.dumps(body) if body is not None else "",
        }

    def context(self):
        return types.SimpleNamespace(aws_request_id="request-id")

    def test_lists_all_routing_profiles(self):
        response = self.module.lambda_handler(
            self.event("GET", "/routing-profiles"),
            self.context(),
        )
        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(
            json.loads(response["body"])["routingProfiles"],
            [{"id": PROFILE_ID, "name": "Test profile"}],
        )

    def test_updates_the_agent_supplied_by_the_browser(self):
        response = self.module.lambda_handler(
            self.event(
                "PUT",
                "/routing-profile",
                {
                    "agentArn": AGENT_ARN,
                    "routingProfileId": PROFILE_ID,
                },
            ),
            self.context(),
        )
        self.assertEqual(response["statusCode"], 200)
        self.connect.update_user_routing_profile.assert_called_once_with(
            RoutingProfileId=PROFILE_ID,
            UserId=CONNECT_USER_ID,
            InstanceId=INSTANCE_ID,
        )

    def test_rejects_an_agent_from_another_instance(self):
        response = self.module.lambda_handler(
            self.event(
                "PUT",
                "/routing-profile",
                {
                    "agentArn": AGENT_ARN.replace(INSTANCE_ID, "other-instance"),
                    "routingProfileId": PROFILE_ID,
                },
            ),
            self.context(),
        )
        self.assertEqual(response["statusCode"], 400)
        self.connect.update_user_routing_profile.assert_not_called()


if __name__ == "__main__":
    unittest.main()
