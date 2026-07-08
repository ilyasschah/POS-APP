using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BookingCommands.Update
{
    public class UpdateBookingCommand : IRequest<bool>
    {
        public UpdateBookingRequest Request { get; }
        public int CompanyId { get; }

        public UpdateBookingCommand(UpdateBookingRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateBookingCommandHandler : IRequestHandler<UpdateBookingCommand, bool>
        {
            private readonly BookingService _bookingService;

            public UpdateBookingCommandHandler(BookingService bookingService)
            {
                _bookingService = bookingService;
            }

            public async Task<bool> Handle(UpdateBookingCommand command, CancellationToken cancellationToken)
            {
                return await _bookingService.UpdateAsync(command.Request, command.CompanyId);
            }
        }
    }
}
