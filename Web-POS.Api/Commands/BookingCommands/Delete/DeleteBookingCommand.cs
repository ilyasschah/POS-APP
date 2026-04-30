using FluentValidation;
using MediatR;
using Api.Services;

namespace Api.Commands.BookingCommands.Delete
{
    public class DeleteBookingCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }

        public DeleteBookingCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteBookingCommandHandler : IRequestHandler<DeleteBookingCommand, bool>
        {
            private readonly BookingService _bookingService;

            public DeleteBookingCommandHandler(BookingService bookingService)
            {
                _bookingService = bookingService;
            }

            public async Task<bool> Handle(DeleteBookingCommand request, CancellationToken cancellationToken)
            {
                return await _bookingService.DeleteAsync(request.Id, request.CompanyId);
            }
        }

        public class DeleteBookingCommandValidator : AbstractValidator<DeleteBookingCommand>
        {
            public DeleteBookingCommandValidator()
            {
                RuleFor(c => c.Id).GreaterThan(0).WithMessage("Booking ID must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
