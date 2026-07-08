using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BookingCommands.Add
{
    public class AddBookingCommand : IRequest<BookingDto>
    {
        public CreateBookingRequest Request { get; set; }
        public int CompanyId { get; }

        public AddBookingCommand(CreateBookingRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class AddBookingCommandHandler : IRequestHandler<AddBookingCommand, BookingDto>
        {
            private readonly BookingService _bookingService;

            public AddBookingCommandHandler(BookingService bookingService)
            {
                _bookingService = bookingService;
            }

            public async Task<BookingDto> Handle(AddBookingCommand request, CancellationToken cancellationToken)
            {
                return await _bookingService.CreateAsync(request.Request, request.CompanyId);
            }
        }

        public class AddBookingCommandValidator : AbstractValidator<AddBookingCommand>
        {
            public AddBookingCommandValidator()
            {
                RuleFor(c => c.Request.ReservationName).NotNull().NotEmpty().WithMessage("Reservation name is required.");
                RuleFor(c => c.Request.StartTime).NotEmpty().WithMessage("Start time is required.");
                RuleFor(c => c.Request.EndTime).NotEmpty().WithMessage("End time is required.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
