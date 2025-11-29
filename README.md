# Nexus

This repository demonstrates the **Nexus** application, a local AI-powered knowledge assistant built with Flutter and the `cactus` package.

## Core Functionality

### 1. Nexus Home (`NexusHomePage`)
The central hub of the application that orchestrates the local AI system.
- **System Initialization**: Manages the lifecycle of the local Language Model (LLM) and RAG (Retrieval-Augmented Generation) engine.
- **Knowledge Base Management**:
  - **Add Documents**: Import PDF, TXT, or MD files to be embedded and stored locally.
  - **Paste Text**: Directly add text snippets to the knowledge base.
  - **Demo Data**: One-click option to load sample data (LinkedIn posts) for testing.
  - **Clear Database**: Reset the knowledge base.
- **Status Monitoring**: Displays real-time system status (e.g., "Downloading model...", "System Ready") and detailed processing logs (chunking, embedding generation).
- **Dashboard**: Shows recent activity and database statistics.

### 2. Nexus Chat (`NexusChatPage`)
An interactive chat interface for querying your knowledge base.
- **RAG-Powered Conversations**: Automatically searches your stored documents for context relevant to your questions before generating answers.
- **Context-Aware**: detailed "thinking" process and cites specific sources used for each response.
- **Model Management**: Switch between different local LLMs (e.g., `qwen3-0.6`) directly from the chat settings.

### 3. Nexus Search (`NexusSearchPage`)
A dedicated semantic search tool for your documents.
- **Vector Search**: Finds relevant document chunks based on meaning, not just keyword matching.
- **Transparency**: Displays similarity scores and previews of the exact content chunks matched from your knowledge base.
