"""
Main entry point for Face Recognition Server
"""
import uvicorn
import logging
from pathlib import Path

def setup_logging():
    """Setup logging configuration"""
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler()
        ]
    )

def main():
    """Main function"""
    # Setup logging
    setup_logging()
    logger = logging.getLogger(__name__)
    
    logger.info("Starting Face Recognition Server...")
    logger.info("Version: 1.0.0")
    logger.info("Debug Mode: True")
    
    # Start server
    logger.info("Starting server on 0.0.0.0:8000")
    
    uvicorn.run(
        "api.advanced_api:app",
        host="0.0.0.0",
        port=5050,
        reload=True,
        log_level="info",
        access_log=True
    )

if __name__ == "__main__":
    main()
