import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class User {
  final String username;
  final String password;

  User({required this.username, required this.password});
}

class Task {
  final String taskId;
  String name;
  String description;

  Task({required this.taskId, required this.name, required this.description});

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'name': name,
      'description': description,
    };
  }
}

List users = [
  User(username: 'admin', password: 'admin123'),
];

final tasks = <Task>[
  Task(
    taskId: '1',
    name: 'Task 1',
    description: 'Description for Task 1',
  ),
  Task(
    taskId: '2',
    name: 'Task 2',
    description: 'Description for Task 2',
  ),
];

bool authenticateUser(String username, String password) {
  final user = users.firstWhere(
    (user) => user.username == username && user.password == password,
    orElse: () => null,
  );
  return user != null;
}

String generateJwt(String username) {
  final jwt = JWT({
    'username': username,
    'exp': DateTime.now().millisecondsSinceEpoch + 3600000, // Expires in 1 hour
  });
  final token = jwt.sign(SecretKey('secret passphrase'));
  return token;
}

Handler userLoginHandler = (Request request) async {
  if (request.method == 'POST') {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final username = body['username'] as String;
    final password = body['password'] as String;

    if (authenticateUser(username, password)) {
      final token = generateJwt(username);
      return Response.ok(jsonEncode({'token': token}));
    }

    return Response.forbidden('Invalid credentials');
  }

  return Response.notFound('Invalid endpoint');
};

Handler createTaskHandler = (Request request) async {
  if (request.method == 'POST') {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final name = body['name'] as String;
    final description = body['description'] as String;

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = Task(taskId: taskId, name: name, description: description);

    tasks.add(task);

    return Response.ok(jsonEncode(task.toMap()));
  }

  return Response.notFound('Invalid endpoint');
};

Handler deleteTaskHandler = (Request request) {
  if (request.method == 'DELETE') {
    final taskId = request.params['taskId'];

    final taskIndex = tasks.indexWhere((task) => task.taskId == taskId);

    if (taskIndex != -1) {
      final deletedTask = tasks.removeAt(taskIndex);
      return Response.ok(jsonEncode(deletedTask.toMap()));
    }

    return Response.notFound('Task not found');
  }

  return Response.notFound('Invalid endpoint');
};

Handler updateTaskHandler = (Request request) async {
  if (request.method == 'PATCH') {
    final taskId = request.params['taskId'];
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final taskIndex = tasks.indexWhere((task) => task.taskId == taskId);

    if (taskIndex != -1) {
      final task = tasks[taskIndex];

      if (body.containsKey('name')) {
        task.name = body['name'] as String;
      }

      if (body.containsKey('description')) {
        task.description = body['description'] as String;
      }

      return Response.ok(jsonEncode(task.toMap()));
    }

    return Response.notFound('Task not found');
  }

  return Response.notFound('Invalid endpoint');
};

Handler getTasksHandler = (Request request) {
  if (request.method == 'GET') {
    final queryParameters = request.requestedUri.queryParameters;
    final offset = int.tryParse(queryParameters['offset'] ?? '0') ?? 0;
    final limit = int.tryParse(queryParameters['limit'] ?? '10') ?? 10;

    final paginatedTasks = tasks.skip(offset).take(limit).map((task) => task.toMap()).toList();    
    return Response.ok(jsonEncode(paginatedTasks));
  }

  return Response.notFound('Invalid endpoint');
};

void main() async {
  final router = Router();
  router.post('/login', userLoginHandler);
  router.post('/tasks', createTaskHandler);
  router.delete('/tasks/<taskId>', deleteTaskHandler);
  router.patch('/tasks/<taskId>', updateTaskHandler);
  router.get('/tasks', getTasksHandler);

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router);
  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running on ${server.address.host}:${server.port}');
}
