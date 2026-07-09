import unittest
from unittest.mock import MagicMock, patch
import flask
import main

class TestCounterAPI(unittest.TestCase):

    @patch('main.db')  # This mocks your Firestore database connection so the test doesn't write to your real DB!
    def test_visitor_counter_success(self, mock_db):
        # 1. Setup our mock database response simulation
        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_doc.get.return_value = 5  # Simulate that the current count in the DB is 5
        
        mock_db.collection.return_value.document.return_value.get.return_value = mock_doc
        mock_db.transaction.return_value = MagicMock()

        # 2. Simulate an incoming HTTP request using Flask (the underlying framework)
        app = flask.Flask('test_app')
        with app.test_request_context(method='GET'):
            from flask import request
            
            # 3. Call your function logic
            response, status_code, headers = main.visitor_counter(request)

            # 4. Assertions (verify the results match expectations)
            self.assertEqual(status_code, 200)
            self.assertEqual(headers.get('Access-Control-Allow-Origin'), '*')
            # Note: Because your transaction uses an inner helper function, 
            # this test validates the status code and headers pass safely.

    def test_cors_preflight(self):
        # Verify that browser security check (OPTIONS) passes correctly
        app = flask.Flask('test_app')
        with app.test_request_context(method='OPTIONS'):
            from flask import request
            response, status_code, headers = main.visitor_counter(request)
            
            self.assertEqual(status_code, 204)
            self.assertEqual(headers.get('Access-Control-Allow-Methods'), 'GET, POST, OPTIONS')