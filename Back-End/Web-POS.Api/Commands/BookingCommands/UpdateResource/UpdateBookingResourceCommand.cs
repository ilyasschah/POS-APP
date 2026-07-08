using MediatR;
using Api.Services;
using Api.Models;

namespace Api.Commands.BookingCommands.UpdateResource
{
    public class UpdateBookingResourceCommand : IRequest<bool>
    {
        public UpdateBookingResourceRequest Request { get; set; }
        public int CompanyId { get; }

        public UpdateBookingResourceCommand(UpdateBookingResourceRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateBookingResourceCommandHandler : IRequestHandler<UpdateBookingResourceCommand, bool>
        {
            private readonly BookingService _bookingService;

            public UpdateBookingResourceCommandHandler(BookingService bookingService)
            {
                _bookingService = bookingService;
            }

            public async Task<bool> Handle(UpdateBookingResourceCommand request, CancellationToken cancellationToken)
            {
                return await _bookingService.UpdateResourceAsync(request.Request, request.CompanyId);
            }
        }
    }
}
