import functions_framework
from google.cloud import firestore

# Initialize the Firestore Client
# It automatically picks up your Project ID when running inside Google Cloud!
db = firestore.Client()

@functions_framework.http
def visitor_counter(request):
    # 1. Handle CORS Preflight Requests
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    # Set standard CORS headers for the actual response
    headers = {
        'Access-Control-Allow-Origin': '*'
    }

    try:
        # 2. Reference your Firestore Document
        # This points exactly to the collection and document you created in Step 8
        doc_ref = db.collection('visitor_counter').document('site_stats')
        
        # 3. Use a Firestore Transaction to safely increment the counter
        # This prevents database conflicts if two people open your resume at the exact same time
        @firestore.transactional
        def update_in_transaction(transaction, doc_ref):
            snapshot = doc_ref.get(transaction=transaction)
            
            # Get the current count (default to 0 if the document somehow looks empty)
            current_count = snapshot.get('count') if snapshot.exists else 0
            new_count = current_count + 1
            
            # Write the incremented number back to Firestore
            transaction.update(doc_ref, {'count': new_count})
            return new_count

        # Execute the transaction
        transaction = db.transaction()
        updated_count = update_in_transaction(transaction, doc_ref)

        # 4. Return the updated count back to your JavaScript front-end!
        return ({"count": updated_count}, 200, headers)

    except Exception as e:
        print(f"Error updating counter: {e}")
        return ({"error": "Internal Server Error"}, 500, headers)