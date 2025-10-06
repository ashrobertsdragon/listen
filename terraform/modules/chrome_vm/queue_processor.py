import requests
import time
import json
import os
from datetime import datetime

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_KEY')
UPLOAD_ENDPOINT = os.getenv('UPLOAD_ENDPOINT')
CHROME_DEBUG_PORT = 9222

def get_pending_url():
    response = requests.get(
        f'{SUPABASE_URL}url_queue',
        headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}'
        },
        params={
            'status': 'eq.pending',
            'order': 'created_at.asc',
            'limit': 1
        }
    )
    response.raise_for_status()
    urls = response.json()
    return urls[0] if urls else None

def mark_processing(url_id):
    requests.patch(
        f'{SUPABASE_URL}url_queue',
        headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        },
        params={'id': f'eq.{url_id}'},
        json={'status': 'processing'}
    )

def mark_completed(url_id):
    requests.patch(
        f'{SUPABASE_URL}url_queue',
        headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        },
        params={'id': f'eq.{url_id}'},
        json={
            'status': 'completed',
            'processed_at': datetime.utcnow().isoformat()
        }
    )

def mark_failed(url_id, error):
    requests.patch(
        f'{SUPABASE_URL}url_queue',
        headers={
            'apikey': SUPABASE_KEY,
            'Authorization': f'Bearer {SUPABASE_KEY}',
            'Content-Type': 'application/json'
        },
        params={'id': f'eq.{url_id}'},
        json={
            'status': 'failed',
            'error_message': str(error),
            'processed_at': datetime.utcnow().isoformat()
        }
    )

def create_tab(url):
    response = requests.get(f'http://localhost:{CHROME_DEBUG_PORT}/json/new?{url}')
    response.raise_for_status()
    return response.json()

def get_page_content(tab_id):
    time.sleep(3)
    
    response = requests.get(f'http://localhost:{CHROME_DEBUG_PORT}/json/list')
    tabs = response.json()
    tab = next((t for t in tabs if t['id'] == tab_id), None)
    
    if not tab:
        raise Exception('Tab not found')
    
    ws_url = tab['webSocketDebuggerUrl']
    
    import websocket
    ws = websocket.create_connection(ws_url)
    
    ws.send(json.dumps({
        'id': 1,
        'method': 'Runtime.evaluate',
        'params': {
            'expression': 'document.documentElement.outerHTML',
            'returnByValue': True
        }
    }))
    
    result = json.loads(ws.recv())
    html = result['result']['result']['value']
    
    ws.close()
    return html, tab['url']

def close_tab(tab_id):
    requests.get(f'http://localhost:{CHROME_DEBUG_PORT}/json/close/{tab_id}')

def process_url(url_record):
    url_id = url_record['id']
    url = url_record['url']
    
    print(f'Processing: {url}')
    mark_processing(url_id)
    
    tab = None
    try:
        tab = create_tab(url)
        tab_id = tab['id']
        
        html, final_url = get_page_content(tab_id)
        
        response = requests.post(
            UPLOAD_ENDPOINT,
            json={'url': final_url, 'html': html},
            headers={'Content-Type': 'application/json'}
        )
        response.raise_for_status()
        
        close_tab(tab_id)
        mark_completed(url_id)
        print(f'Completed: {url}')
        
    except Exception as e:
        print(f'Failed: {url} - {e}')
        if tab:
            close_tab(tab['id'])
        mark_failed(url_id, str(e))

def main():
    print('Queue processor started')
    while True:
        try:
            url_record = get_pending_url()
            if url_record:
                process_url(url_record)
                time.sleep(2)
            else:
                time.sleep(10)
        except KeyboardInterrupt:
            print('Shutting down')
            break
        except Exception as e:
            print(f'Error: {e}')
            time.sleep(10)

if __name__ == '__main__':
    main()
