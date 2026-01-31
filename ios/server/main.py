import os

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import AsyncOpenAI

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.post("/session")
async def create_session():
    """Create an OpenAI Realtime API ephemeral key."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY not set")

    client = AsyncOpenAI(api_key=api_key)

    try:
        response = await client.realtime.client_secrets.create(
            expires_after={"anchor": "created_at", "seconds": 600},
            session={
                "type": "realtime",
                "model": "gpt-4o-realtime-preview",
            },
        )
        # Return in format iOS app expects
        return {
            "client_secret": {
                "value": response.value,
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {str(e)}")
