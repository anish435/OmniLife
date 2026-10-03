import '../../entities/calendar_event.dart';
import '../../repositories/calendar_repository.dart';

class CreateEventUseCase {
  const CreateEventUseCase(this._repository);

  final CalendarRepository _repository;

  Future<CalendarEvent> call(CalendarEvent event) => _repository.createEvent(event);
}

class UpdateEventUseCase {
  const UpdateEventUseCase(this._repository);

  final CalendarRepository _repository;

  Future<CalendarEvent> call(CalendarEvent event) => _repository.updateEvent(event);
}

class DeleteEventUseCase {
  const DeleteEventUseCase(this._repository);

  final CalendarRepository _repository;

  Future<void> call(String id) => _repository.deleteEvent(id);
}
