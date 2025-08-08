import requests
import json
import time
import sys
from datetime import datetime

class CloudflareManager:
    def __init__(self, token, zone_id, domain):
        self.token = token
        self.zone_id = zone_id  
        self.domain = domain
        self.base_url = "https://api.cloudflare.com/client/v4"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
    
    def purge_everything(self):
        """Purge entire cache for the zone"""
        url = f"{self.base_url}/zones/{self.zone_id}/purge_cache"
        data = {"purge_everything": True}
        
        print(f"Purging entire cache for {self.domain}...")
        response = requests.post(url, headers=self.headers, json=data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"Cache purged successfully at {datetime.now()}")
            return {"success": True, "result": result}
        else:
            print(f"Cache purge failed: {response.status_code} - {response.text}")
            return {"success": False, "error": response.text}
    
    def get_zone_settings(self):
        """Get current zone settings"""
        url = f"{self.base_url}/zones/{self.zone_id}/settings"
        
        response = requests.get(url, headers=self.headers)
        
        if response.status_code == 200:
            return {"success": True, "settings": response.json()}
        else:
            return {"success": False, "error": response.text}
    
    def get_dns_records(self):
        """Get all DNS records for the zone"""
        url = f"{self.base_url}/zones/{self.zone_id}/dns_records"
        
        response = requests.get(url, headers=self.headers)
        
        if response.status_code == 200:
            return {"success": True, "records": response.json()}
        else:
            return {"success": False, "error": response.text}
    
    def verify_domain_status(self):
        """Comprehensive domain verification"""
        print(f"Verifying domain status for {self.domain}...")
        
        # Test multiple URLs
        test_urls = [
            f"https://{self.domain}",
            f"https://www.{self.domain}",
            f"http://{self.domain}",
            f"http://www.{self.domain}"
        ]
        
        results = {}
        for url in test_urls:
            try:
                response = requests.get(url, timeout=10, allow_redirects=True)
                results[url] = {
                    "status_code": response.status_code,
                    "content_length": len(response.content),
                    "headers": dict(response.headers),
                    "final_url": response.url
                }
                print(f"SUCCESS {url}: HTTP {response.status_code} ({len(response.content)} bytes)")
            except Exception as e:
                results[url] = {"error": str(e)}
                print(f"ERROR {url}: {str(e)}")
        
        return results

def main():
    """Main execution function"""
    print("Professional Cloudflare Management - Best Casino Portal")
    print("=" * 60)
    
    # Initialize Cloudflare manager
    cf = CloudflareManager(
        token="pe2L5nDoK0kKvpGVkRSm4P48FExlWfbTZdOZfhXF",
        zone_id="7e35370f0b0046096a758f4df76bf2d0",
        domain="bestcasinoportal.com"
    )
    
    # 1. Get current zone settings
    print("\n1. Checking current zone settings...")
    settings = cf.get_zone_settings()
    if settings["success"]:
        print("Zone settings retrieved successfully")
    
    # 2. Get DNS records
    print("\n2. Checking DNS records...")
    dns_records = cf.get_dns_records()
    if dns_records["success"]:
        records = dns_records["records"]["result"]
        for record in records:
            if record["type"] in ["A", "CNAME"]:
                name = record["name"]
                rtype = record["type"]
                content = record["content"]
                proxied = record["proxied"]
                print(f"DNS: {name}: {rtype} -> {content} (Proxied: {proxied})")
    
    # 3. Purge entire cache
    print("\n3. Purging entire cache...")
    purge_result = cf.purge_everything()
    
    # 4. Wait for cache purge to propagate
    print("\n4. Waiting for cache purge to propagate...")
    for i in range(5, 0, -1):
        print(f"Waiting {i} seconds...")
        time.sleep(1)
    
    # 5. Verify domain status
    print("\n5. Verifying domain accessibility...")
    verification_results = cf.verify_domain_status()
    
    # 6. Summary report
    print("\nVERIFICATION SUMMARY")
    print("=" * 40)
    
    cache_purged = purge_result.get("success", False)
    print(f"Cache Purged: {
YES if cache_purged else NO}")
    
    # Check if any URL returned 200
    successful_urls = []
    for url, result in verification_results.items():
        if isinstance(result, dict) and result.get("status_code") == 200:
            successful_urls.append(url)
    
    print(f"Working URLs: {len(successful_urls)}/{len(verification_results)}")
    for url in successful_urls:
        print(f"  SUCCESS: {url}")
    
    # Final status
    if cache_purged and successful_urls:
        print("\nSUCCESS: Cache purged and domain is accessible!")
        return True
    else:
        print("\nISSUES DETECTED: Manual investigation required")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

