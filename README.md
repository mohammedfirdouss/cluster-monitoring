# 📝 Task Manager CLI

A simple command-line interface (CLI) task manager application built with Go and Cobra. This application allows users to manage their tasks efficiently through a set of commands.

## ✨ Features
- ➕ Add new tasks.
- 📋 List all tasks.
- ✅ Mark tasks as completed.
- 💾 Persistent storage of tasks in a JSON file.
- Clear all tasks when needed.

## 🚀 Installation

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/mohammedfirdouss/go-task-manager.git
   cd go-task-manager
   ```
2. Build the CLI:
   ```bash
   go build -o task-manager cli/main.go
   ```

3. Run the CLI:
   ```bash
   ./task-manager
   ```

# 📚 Usage

### ➕ Add a Task
``` bash
./task-manager add "Your task description"
```

📋 List All Tasks
```bash
./task-manager list
```

### ✅ Complete a Task
```bash
./task-manager complete <task ID>
```

### To clear all tasks
```bash
./task-manager clear
```
![Screenshot (1348)](https://github.com/user-attachments/assets/69fdda36-a60f-4edb-b93c-6a8a50b6f5ae)
![Screenshot (1350)](https://github.com/user-attachments/assets/5b3da7ea-bb56-42b4-a08e-d29be34cee69)
![Screenshot (1351)](https://github.com/user-attachments/assets/1be0aa71-af60-42cb-aca8-7d77db9d1c46)


## 🤝 Contributing
Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch:
   ```bash
   git checkout -b feature/your-feature
   ```
3. Make your changes and commit them:
   ```bash
   git commit -m "Add your feature"
   ```
4. Push to the branch:
   ```bash
   git push origin feature/your-feature
   ```
5. Open a pull request.


Thank you for contributing! 😊
