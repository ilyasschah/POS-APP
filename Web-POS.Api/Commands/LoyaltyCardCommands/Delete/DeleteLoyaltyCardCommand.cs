// FILE: Products.Api.Commands\LoyaltyCardCommands\Delete\DeleteLoyaltyCardCommand.cs

using MediatR;
using Products.Api.Services;

namespace Products.Api.Commands.LoyaltyCardCommands.Delete;

public class DeleteLoyaltyCardCommand : IRequest<bool>
{
    public int Id { get; }

    public DeleteLoyaltyCardCommand(int id)
    {
        Id = id;
    }

    public class DeleteLoyaltyCardCommandHandler : IRequestHandler<DeleteLoyaltyCardCommand, bool>
    {
        private readonly LoyaltyCardService _service;

        public DeleteLoyaltyCardCommandHandler(LoyaltyCardService service)
        {
            _service = service;
        }

        public Task<bool> Handle(DeleteLoyaltyCardCommand request, CancellationToken cancellationToken)
        {
            return _service.Delete(request.Id);
        }
    }
}
