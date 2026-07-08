using FluentValidation;
using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BookingCommands.UpdateStatus
{
    public class UpdateBookingStatusCommand : IRequest<bool>
    {
        public UpdateBookingStatusRequest Request { get; set; }
        public int CompanyId { get; }

        public UpdateBookingStatusCommand(UpdateBookingStatusRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateBookingStatusCommandHandler : IRequestHandler<UpdateBookingStatusCommand, bool>
        {
            private readonly BookingService _bookingService;

            public UpdateBookingStatusCommandHandler(BookingService bookingService)
            {
                _bookingService = bookingService;
            }

            public async Task<bool> Handle(UpdateBookingStatusCommand request, CancellationToken cancellationToken)
            {
                return await _bookingService.UpdateStatusAsync(request.Request, request.CompanyId);
            }
        }

        public class UpdateBookingStatusCommandValidator : AbstractValidator<UpdateBookingStatusCommand>
        {
            public UpdateBookingStatusCommandValidator()
            {
                RuleFor(c => c.Request.BookingId).GreaterThan(0).WithMessage("Booking ID must be valid.");
                RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
